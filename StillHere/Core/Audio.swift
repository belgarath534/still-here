import Foundation

/// Mono audio samples.
final class PCM {
    let samples: [Float]
    let rate: Double
    init(_ samples: [Float], rate: Double = Synth.SR) { self.samples = samples; self.rate = rate }
    var duration: Double { Double(samples.count) / rate }
    func reversed() -> PCM { PCM(samples.reversed(), rate: rate) }
}

enum Source {
    /// A sound file from the app bundle, loaded with `load`.
    case named(String)
    /// A sound made in code. The key is used to cache it; the closure only runs if it's actually played.
    case synth(String, () -> PCM)
}

struct PlayParams {
    var x = 0.0, y = 0.0, z = -1.0
    var gain = 1.0, rate = 1.0
    var lowpass: Double? = nil, highpass: Double? = nil
    var loop = false, keep = false
    /// false: plays straight to both ears (rain, engine, wind), true: placed around you in 3D
    var spatial = true
    var to: [Double]? = nil, toSec = 2.0
}

/// What the game needs from the sound system. The iPhone version uses AVAudioEngine;
/// the tests use a silent stand-in that only knows how long each file is.
protocol AudioBackend: AnyObject {
    @MainActor func load(_ names: [String]) async -> Bool
    func unload(_ names: [String])
    /// seconds, nil when that sound isn't loaded
    func duration(_ name: String) -> Double?
    func pcm(_ name: String) -> PCM?
    /// add, replace or (with nil) remove a named sound, e.g. your recorded voice
    func store(_ name: String, _ pcm: PCM?)
    @discardableResult func play(_ src: Source, _ p: PlayParams) -> Int
    func stopAll(includeKeep: Bool)
    /// looping background layers like rain or the car engine, faded to `gain`
    func setBed(_ key: String, _ src: Source, _ p: PlayParams, gain: Double, fade: Double)
    func setBedLowpass(_ key: String, _ freq: Double, fade: Double)
    /// fade `name` to `vol` and every other track out
    func music(_ name: String, vol: Double, fade: Double)
    func musicCut()
    func setMaster(_ v: Double)
    func setMusicVolume(_ v: Double)
    func suspend()
    func resume()
    func haptic(_ kind: String)
    /// record from the microphone; the result never leaves the device
    @MainActor func record(seconds: Double) async throws -> PCM
}

/// Does nothing. Used until the real one is plugged in.
final class SilentAudio: AudioBackend {
    func load(_ names: [String]) async -> Bool { true }
    func unload(_ names: [String]) {}
    func duration(_ name: String) -> Double? { nil }
    func pcm(_ name: String) -> PCM? { nil }
    func store(_ name: String, _ pcm: PCM?) {}
    func play(_ src: Source, _ p: PlayParams) -> Int { 0 }
    func stopAll(includeKeep: Bool) {}
    func setBed(_ key: String, _ src: Source, _ p: PlayParams, gain: Double, fade: Double) {}
    func setBedLowpass(_ key: String, _ freq: Double, fade: Double) {}
    func music(_ name: String, vol: Double, fade: Double) {}
    func musicCut() {}
    func setMaster(_ v: Double) {}
    func setMusicVolume(_ v: Double) {}
    func suspend() {}
    func resume() {}
    func haptic(_ kind: String) {}
    func record(seconds: Double) async throws -> PCM { throw CancellationError() }
}

/// Sound made in code: oscillators, filtered noise, envelopes. Matches the Web Audio graphs of the web version.
enum Synth {
    static let SR = 44100.0

    struct Biquad {
        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        enum Kind { case lowpass, highpass, bandpass }
        let kind: Kind
        init(_ kind: Kind, _ freq: Double, q: Double? = nil) { self.kind = kind; set(freq, q: q) }
        mutating func set(_ freq: Double, q: Double? = nil) {
            let f = Swift.min(Swift.max(freq, 10), SR * 0.45)
            let Q = q ?? (kind == .bandpass ? 1 : 0.7071)
            let w = 2 * Double.pi * f / SR, c = cos(w), alpha = sin(w) / (2 * Q)
            let a0 = 1 + alpha
            switch kind {
            case .lowpass: b0 = (1 - c) / 2; b1 = 1 - c; b2 = (1 - c) / 2
            case .highpass: b0 = (1 + c) / 2; b1 = -(1 + c); b2 = (1 + c) / 2
            case .bandpass: b0 = alpha; b1 = 0; b2 = -alpha
            }
            b0 /= a0; b1 /= a0; b2 /= a0; a1 = -2 * c / a0; a2 = (1 - alpha) / a0
        }
        mutating func run(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }
    }

    static func noiseSample() -> Double { Double.random(in: -1...1) }

    /// One sample of an oscillator at `phase` (0..1). Saw and square are softened at their jumps.
    static func osc(_ type: String, _ phase: Double, _ dt: Double) -> Double {
        func blep(_ t: Double) -> Double {
            if t < dt { let x = t / dt; return x + x - x * x - 1 }
            if t > 1 - dt { let x = (t - 1) / dt; return x * x + x + x + 1 }
            return 0
        }
        switch type {
        case "square":
            var v = phase < 0.5 ? 1.0 : -1.0
            v += blep(phase); v -= blep((phase + 0.5).truncatingRemainder(dividingBy: 1))
            return v
        case "sawtooth":
            return 2 * phase - 1 - blep(phase)
        case "triangle":
            return phase < 0.5 ? 4 * phase - 1 : 3 - 4 * phase
        default:
            return sin(2 * Double.pi * phase)
        }
    }

    /// value of an exponential ramp from a to b, at fraction k (0..1)
    static func expRamp(_ a: Double, _ b: Double, _ k: Double) -> Double { a * pow(b / a, Swift.min(Swift.max(k, 0), 1)) }

    /// Web Audio style tone: frequency f (sliding to f2), gain rising over `attack` then fading out by `dur`.
    static func tone(type: String, f: Double, f2: Double?, dur: Double, gain: Double, attack: Double) -> PCM {
        let n = Int((dur + 0.05) * SR)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / SR
            let freq = f2.map { expRamp(f, $0, t / dur) } ?? f
            let env = t < attack ? expRamp(0.0001, gain, t / attack) : expRamp(gain, 0.0001, (t - attack) / Swift.max(dur - attack, 0.001))
            out[i] = Float(osc(type, phase, freq / SR) * (t > dur ? 0 : env))
            phase += freq / SR
            if phase >= 1 { phase -= 1 }
        }
        return PCM(out)
    }

    /// Filtered noise with frequency and gain envelopes given as functions of time.
    static func noiseBurst(_ dur: Double, kind: Biquad.Kind, q: Double? = nil, freq: (Double) -> Double, gain: (Double) -> Double) -> PCM {
        let n = Int(dur * SR)
        var out = [Float](repeating: 0, count: n)
        var bq = Biquad(kind, freq(0), q: q)
        for i in 0..<n {
            let t = Double(i) / SR
            if i % 32 == 0 { bq.set(freq(t), q: q) }
            out[i] = Float(bq.run(noiseSample()) * gain(t))
        }
        return PCM(out)
    }

    /// A seamless loop: renders a bit extra and crossfades the end into the start.
    static func loop(_ seconds: Double, warmup: Double = 0.5, _ next: (Double) -> Double) -> PCM {
        let n = Int(seconds * SR), fade = Int(0.25 * SR), warm = Int(warmup * SR)
        var raw = [Double](repeating: 0, count: warm + n + fade)
        for i in 0..<raw.count { raw[i] = next(Double(i) / SR) }
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n { out[i] = Float(raw[warm + i]) }
        for i in 0..<fade {
            let k = Double(i) / Double(fade)
            out[i] = Float(raw[warm + i] * k + raw[warm + n + i] * (1 - k))
        }
        return PCM(out)
    }

    static func noiseLoop(_ kind: Biquad.Kind, _ freq: Double, q: Double? = nil, seconds: Double = 4) -> PCM {
        var bq = Biquad(kind, freq, q: q)
        return loop(seconds) { _ in bq.run(noiseSample()) }
    }

    /// The car engine: a low sawtooth with a little wobble, through a low filter.
    static func engineLoop() -> PCM {
        var bq = Biquad(.lowpass, 240)
        var phase = 0.0
        return loop(1.0) { t in
            let f = 38 + 3 * sin(2 * Double.pi * 6 * t)
            phase += f / SR; if phase >= 1 { phase -= 1 }
            return bq.run(osc("sawtooth", phase, f / SR))
        }
    }

    /// Electrical hum: 120 Hz and two overtones.
    static func humLoop() -> PCM {
        loop(1.0, warmup: 0) { t in
            0.5 * sin(2 * .pi * 120 * t) + 0.25 * sin(2 * .pi * 240 * t) + 0.12 * sin(2 * .pi * 360 * t)
        }
    }

    /// Wind: noise through a filter that slowly opens and closes.
    static func windLoop() -> PCM {
        var bq = Biquad(.lowpass, 500)
        var i = 0
        return loop(2 / 0.13) { t in
            if i % 64 == 0 { bq.set(500 + 250 * sin(2 * .pi * 0.13 * t)) }
            i += 1
            return bq.run(noiseSample())
        }
    }

    /// An old phone ringing: two tones chopped 22 times a second.
    static func ringBurst() -> PCM {
        let n = Int(1.6 * SR)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / SR
            let chop = sin(2 * .pi * 22 * t) >= 0 ? 0.06 : -0.06
            out[i] = Float((sin(2 * .pi * 880 * t) + sin(2 * .pi * 1060 * t)) * chop)
        }
        return PCM(out)
    }

    /// A police siren sweeping up and down.
    static func siren(_ dur: Double) -> PCM {
        let n = Int((dur + 0.1) * SR)
        var out = [Float](repeating: 0, count: n)
        var bq = Biquad(.lowpass, 1800)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / SR
            let k = (t.truncatingRemainder(dividingBy: 1.2)) / 1.2
            let f = k < 0.5 ? 650 + 700 * (k * 2) : 1350 - 700 * ((k - 0.5) * 2)
            let env = t < 1 ? expRamp(0.0001, 0.07, t) : t < dur - 1.5 ? 0.07 : expRamp(0.07, 0.0001, (t - (dur - 1.5)) / 1.5)
            phase += f / SR; if phase >= 1 { phase -= 1 }
            out[i] = Float(bq.run(osc("square", phase, f / SR)) * (t > dur ? 0 : env))
        }
        return PCM(out)
    }
}
