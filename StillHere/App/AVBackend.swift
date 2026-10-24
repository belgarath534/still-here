import AVFoundation
import UIKit

/// The iPhone's sound system for the game: 3D sound through AVAudioEngine's environment node
/// (HRTF, so headphones place sounds left, right, in front, behind and above), looping layers,
/// music, vibration and the microphone.
final class AVBackend: AudioBackend {
    private let engine = AVAudioEngine()
    private let env = AVAudioEnvironmentNode()
    private let flatMix = AVAudioMixerNode()
    private let preMix = AVAudioMixerNode()
    private let limiter: AVAudioUnitEffect
    private let mono = AVAudioFormat(standardFormatWithSampleRate: Synth.SR, channels: 1)!
    private let stereo = AVAudioFormat(standardFormatWithSampleRate: Synth.SR, channels: 2)!

    /// One playing sound: player -> filters -> mixer (which carries its 3D position) -> environment.
    private final class Voice {
        let player = AVAudioPlayerNode()
        let eq = AVAudioUnitEQ(numberOfBands: 2)
        let mixer = AVAudioMixerNode()
        let spatial: Bool
        var busy = false
        var keep = false
        var startedAt = 0.0
        var serial = 0
        var move: Task<Void, Never>? = nil
        init(spatial: Bool) { self.spatial = spatial }
    }
    private var voices: [Voice] = []

    private final class Bed {
        let voice: Voice
        var gain = 0.0
        var running = false
        var fade: Task<Void, Never>? = nil
        var src: Source
        init(_ v: Voice, _ src: Source) { voice = v; self.src = src }
    }
    private var beds: [String: Bed] = [:]

    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var synthCache: [String: AVAudioPCMBuffer] = [:]

    private var tracks: [String: AVAudioPlayer] = [:]
    private var musicTarget: [String: Double] = [:]
    private var musicStop: [String: Task<Void, Never>] = [:]
    private var masterVol = 1.0, musicVol = 1.0
    private var suspended = false

    private let lightTap = UIImpactFeedbackGenerator(style: .light)
    private let heavyTap = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidTap = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
        configureSession(record: false)
        buildGraph()
        startEngine()
        observe()
    }

    private func configureSession(record: Bool) {
        let s = AVAudioSession.sharedInstance()
        do {
            if record { try s.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker]) }
            else { try s.setCategory(.playback, mode: .default, options: []) }
            try s.setActive(true)
        } catch { print("audio session: \(error)") }
    }

    private func buildGraph() {
        engine.attach(env); engine.attach(flatMix); engine.attach(preMix); engine.attach(limiter)
        env.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        env.distanceAttenuationParameters.referenceDistance = 1
        env.distanceAttenuationParameters.rolloffFactor = 1.2
        env.distanceAttenuationParameters.maximumDistance = 1000
        env.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        env.reverbParameters.enable = false
        engine.connect(env, to: preMix, format: stereo)
        engine.connect(flatMix, to: preMix, format: stereo)
        engine.connect(preMix, to: limiter, format: stereo)
        engine.connect(limiter, to: engine.mainMixerNode, format: stereo)
        AudioUnitSetParameter(limiter.audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, -4, 0)
        AudioUnitSetParameter(limiter.audioUnit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, 6, 0)
        for i in 0..<22 { voices.append(makeVoice(spatial: i < 16)) }
    }

    private func makeVoice(spatial: Bool) -> Voice {
        let v = Voice(spatial: spatial)
        engine.attach(v.player); engine.attach(v.eq); engine.attach(v.mixer)
        engine.connect(v.player, to: v.eq, format: mono)
        engine.connect(v.eq, to: v.mixer, format: mono)
        engine.connect(v.mixer, to: spatial ? env : flatMix, format: mono)
        if spatial {
            v.mixer.renderingAlgorithm = .HRTFHQ
            v.mixer.sourceMode = .pointSource
        }
        v.eq.bands[0].filterType = .highPass
        v.eq.bands[1].filterType = .lowPass
        for b in v.eq.bands { b.bypass = true; b.bandwidth = 0.5 }
        return v
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do { try engine.start() } catch { print("engine start: \(error)") }
        engine.mainMixerNode.outputVolume = Float(masterVol)
    }

    private func observe() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, !self.suspended else { return }
            self.startEngine()
            for (_, b) in self.beds where b.running { b.running = false; self.startBed(b) }
        }
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { n in
            guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            openPause()
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { n in
            // headphones unplugged: pause so nothing jumps out of the speaker
            guard let raw = n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            openPause()
        }
    }

    /* ---------- loading ---------- */

    @MainActor func load(_ names: [String]) async -> Bool {
        let todo = names.filter { buffers[$0] == nil }
        let fmt = mono
        let decoded: [(String, AVAudioPCMBuffer?)] = await withTaskGroup(of: (String, AVAudioPCMBuffer?).self) { group in
            for n in todo { group.addTask { (n, AVBackend.decode(n, to: fmt)) } }
            var out: [(String, AVAudioPCMBuffer?)] = []
            for await r in group { out.append(r) }
            return out
        }
        var ok = true
        for (n, b) in decoded {
            if let b { buffers[n] = b } else { ok = false; print("could not load \(n)") }
        }
        return ok
    }

    /// Reads an mp3 from the app and converts it to mono 44.1 kHz.
    private static func decode(_ name: String, to fmt: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return nil }
        return decodeFile(url, to: fmt)
    }
    private static func decodeFile(_ url: URL, to fmt: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let inFmt = file.processingFormat
        guard let raw = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        do { try file.read(into: raw) } catch { return nil }
        if inFmt.sampleRate == fmt.sampleRate && inFmt.channelCount == 1 { return raw }
        guard let conv = AVAudioConverter(from: inFmt, to: fmt) else { return nil }
        let cap = AVAudioFrameCount(Double(raw.frameLength) * fmt.sampleRate / inFmt.sampleRate) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap) else { return nil }
        var fed = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return raw
        }
        return err == nil ? out : nil
    }

    func unload(_ names: [String]) { for n in names { buffers[n] = nil } }
    func duration(_ name: String) -> Double? { buffers[name].map { Double($0.frameLength) / $0.format.sampleRate } }

    func pcm(_ name: String) -> PCM? {
        guard let b = buffers[name], let ch = b.floatChannelData else { return nil }
        return PCM(Array(UnsafeBufferPointer(start: ch[0], count: Int(b.frameLength))), rate: b.format.sampleRate)
    }
    func store(_ name: String, _ pcm: PCM?) {
        guard let pcm else { buffers[name] = nil; return }
        buffers[name] = makeBuffer(pcm)
    }
    private func makeBuffer(_ pcm: PCM) -> AVAudioPCMBuffer? {
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: pcm.rate, channels: 1),
              let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(max(pcm.samples.count, 1))) else { return nil }
        b.frameLength = AVAudioFrameCount(pcm.samples.count)
        pcm.samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress { b.floatChannelData![0].update(from: base, count: pcm.samples.count) }
        }
        if pcm.rate != Synth.SR { return AVBackend.resample(b, to: mono) }
        return b
    }
    private static func resample(_ b: AVAudioPCMBuffer, to fmt: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let conv = AVAudioConverter(from: b.format, to: fmt),
              let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(Double(b.frameLength) * fmt.sampleRate / b.format.sampleRate) + 1024) else { return nil }
        var fed = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return b
        }
        return err == nil ? out : nil
    }

    private func buffer(_ src: Source) -> AVAudioPCMBuffer? {
        switch src {
        case .named(let n): return buffers[n]
        case .synth(let key, let make):
            if let b = synthCache[key] { return b }
            if synthCache.count > 400 { synthCache = synthCache.filter { !$0.key.hasPrefix("tone|") } }
            let b = makeBuffer(make())
            synthCache[key] = b
            return b
        }
    }

    /* ---------- playing ---------- */

    private func setup(_ v: Voice, _ p: PlayParams) {
        v.eq.bands[0].bypass = p.highpass == nil
        if let hp = p.highpass { v.eq.bands[0].frequency = Float(hp) }
        v.eq.bands[1].bypass = p.lowpass == nil
        if let lp = p.lowpass { v.eq.bands[1].frequency = Float(min(lp, 20000)) }
        v.eq.globalGain = Float(min(max(20 * log10(max(p.gain, 0.00001)), -96), 24))
        if v.spatial {
            v.mixer.position = AVAudio3DPoint(x: Float(p.x), y: Float(p.y), z: Float(p.z))
            v.mixer.rate = Float(min(max(p.rate, 0.5), 2))
        }
    }

    private func grab(spatial: Bool) -> Voice {
        let pool = voices.filter { $0.spatial == spatial }
        if let free = pool.first(where: { !$0.busy }) { return free }
        return pool.filter { !$0.keep }.min { $0.startedAt < $1.startedAt } ?? pool[0]
    }

    @discardableResult
    func play(_ src: Source, _ p: PlayParams) -> Int {
        guard !suspended, let buf = buffer(src) else { return 0 }
        startEngine()
        let v = grab(spatial: p.spatial)
        v.move?.cancel()
        v.player.stop()
        setup(v, p)
        v.busy = true; v.keep = p.keep
        v.serial += 1
        let serial = v.serial
        v.startedAt = CACurrentMediaTime()
        v.player.scheduleBuffer(buf, at: nil, options: p.loop ? .loops : [], completionCallbackType: .dataPlayedBack) { [weak v] _ in
            DispatchQueue.main.async { if let v, v.serial == serial { v.busy = false } }
        }
        v.player.play()
        if let to = p.to, v.spatial { glide(v, from: [p.x, p.y, p.z], to: to, seconds: p.toSec) }
        return serial
    }

    private func glide(_ v: Voice, from: [Double], to: [Double], seconds: Double) {
        let t0 = CACurrentMediaTime()
        v.move = Task { @MainActor [weak v] in
            while let v, !Task.isCancelled {
                let k = min((CACurrentMediaTime() - t0) / max(seconds, 0.01), 1)
                v.mixer.position = AVAudio3DPoint(x: Float(from[0] + (to[0] - from[0]) * k), y: Float(from[1] + (to[1] - from[1]) * k), z: Float(from[2] + (to[2] - from[2]) * k))
                if k >= 1 { break }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    func stopAll(includeKeep: Bool) {
        for v in voices where v.busy && (includeKeep || !v.keep) {
            v.move?.cancel()
            v.serial += 1
            v.player.stop()
            v.busy = false
        }
    }

    /* ---------- looping layers ---------- */

    func setBed(_ key: String, _ src: Source, _ p: PlayParams, gain: Double, fade: Double) {
        let bed: Bed
        if let b = beds[key] { bed = b }
        else {
            if gain <= 0 { return }
            bed = Bed(makeVoice(spatial: p.spatial), src)
            bed.voice.mixer.outputVolume = 0
            beds[key] = bed
            startEngine()
        }
        setup(bed.voice, p)
        bed.voice.eq.globalGain = 0
        let from = Double(bed.voice.mixer.outputVolume)
        bed.gain = gain
        if gain > 0 && !bed.running { startBed(bed) }
        bed.fade?.cancel()
        let t0 = CACurrentMediaTime()
        bed.fade = Task { @MainActor [weak self, weak bed] in
            while let bed, !Task.isCancelled {
                let k = fade <= 0 ? 1 : min((CACurrentMediaTime() - t0) / fade, 1)
                bed.voice.mixer.outputVolume = Float(from + (gain - from) * k)
                if k >= 1 {
                    if gain <= 0 { bed.voice.player.stop(); bed.running = false }
                    break
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            _ = self
        }
    }

    private func startBed(_ bed: Bed) {
        guard let buf = buffer(bed.src) else { return }
        bed.voice.player.stop()
        bed.voice.player.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
        bed.voice.player.play()
        bed.running = true
    }

    func setBedLowpass(_ key: String, _ freq: Double, fade: Double) {
        guard let b = beds[key] else { return }
        b.voice.eq.bands[1].bypass = false
        b.voice.eq.bands[1].frequency = Float(freq)
    }

    /* ---------- music ---------- */

    private func musicPlayer(_ name: String) -> AVAudioPlayer? {
        if let p = tracks[name] { return p }
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3"), let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.numberOfLoops = -1
        p.volume = 0
        p.prepareToPlay()
        tracks[name] = p
        return p
    }

    func music(_ name: String, vol: Double, fade: Double) {
        for (n, _) in musicTarget where n != name { fadeMusic(n, to: 0, fade: fade) }
        fadeMusic(name, to: vol, fade: fade)
    }
    private func fadeMusic(_ name: String, to vol: Double, fade: Double) {
        musicTarget[name] = vol
        musicStop[name]?.cancel()
        guard let p = musicPlayer(name) else { return }
        if vol > 0 {
            if !p.isPlaying && !suspended { p.play() }
            p.setVolume(Float(vol * musicVol * masterVol), fadeDuration: max(fade, 0.01))
        } else {
            p.setVolume(0, fadeDuration: max(fade, 0.01))
            musicStop[name] = Task { @MainActor [weak p] in
                try? await Task.sleep(nanoseconds: UInt64((fade + 0.2) * 1_000_000_000))
                if !Task.isCancelled { p?.pause() }
            }
            musicTarget[name] = nil
        }
    }
    func musicCut() {
        for (n, p) in tracks { musicStop[n]?.cancel(); p.volume = 0; p.pause() }
        musicTarget = [:]
    }

    func setMaster(_ v: Double) {
        masterVol = v
        engine.mainMixerNode.outputVolume = Float(v)
        applyMusicVolume()
    }
    func setMusicVolume(_ v: Double) { musicVol = v; applyMusicVolume() }
    private func applyMusicVolume() {
        for (n, t) in musicTarget { tracks[n]?.volume = Float(t * musicVol * masterVol) }
    }

    /* ---------- pause ---------- */

    func suspend() {
        suspended = true
        engine.pause()
        for (n, _) in musicTarget { tracks[n]?.pause() }
    }
    func resume() {
        suspended = false
        configureSession(record: false)
        startEngine()
        for (n, t) in musicTarget where t > 0 { tracks[n]?.play() }
    }

    /* ---------- vibration ---------- */

    func haptic(_ kind: String) {
        switch kind {
        case "heart":
            heavyTap.impactOccurred(intensity: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in self?.heavyTap.impactOccurred(intensity: 0.35) }
        case "knock": rigidTap.impactOccurred(intensity: 0.8)
        case "boom", "scream": heavyTap.impactOccurred(intensity: 1)
        default:
            if kind.hasPrefix("buzz") {
                // a phone vibrating on a nightstand: pairs of short pulses
                let times = Int(kind.dropFirst(4)) ?? 1
                for i in 0..<times {
                    for k in [0.0, 0.5] {
                        for j in 0..<4 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.6 + k + Double(j) * 0.09) { [weak self] in
                                self?.lightTap.impactOccurred(intensity: 0.9)
                            }
                        }
                    }
                }
            }
        }
    }

    /* ---------- microphone ---------- */

    enum MicError: Error { case denied, failed }

    @MainActor func record(seconds: Double) async throws -> PCM {
        guard await AVAudioApplication.requestRecordPermission() else { throw MicError.denied }
        engine.pause()
        configureSession(record: true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stillhere-voice.caf")
        defer {
            try? FileManager.default.removeItem(at: url)
            configureSession(record: false)
            startEngine()
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Synth.SR, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        guard rec.record(forDuration: seconds) else { throw MicError.failed }
        try await Task.sleep(nanoseconds: UInt64((seconds + 0.3) * 1_000_000_000))
        rec.stop()
        guard let b = AVBackend.decodeFile(url, to: mono), let ch = b.floatChannelData else { throw MicError.failed }
        // make a quiet whisper loud enough to hear
        let n = Int(b.frameLength)
        var peak: Float = 0.0001
        for i in 0..<n { peak = max(peak, abs(ch[0][i])) }
        let g = min(0.9 / peak, 30)
        return PCM((0..<n).map { ch[0][$0] * g }, rate: Synth.SR)
    }
}
