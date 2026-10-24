import Foundation

// Every sound the story uses, by the same names as the web version.

private var delayed: [Int: (task: Task<Void, Never>, keep: Bool)] = [:]
private var delaySeq = 0

private func params(_ o: Opts) -> PlayParams {
    var p = PlayParams()
    p.x = o.x ?? 0; p.y = o.y ?? 0; p.z = o.z ?? -1
    p.gain = o.gain ?? 1; p.rate = o.rate ?? 1
    p.loop = o.loop; p.keep = o.keep
    if o.phone {
        p.highpass = 350
        p.lowpass = Swift.min(o.lowpass ?? 3200, 3200)
    } else { p.lowpass = o.lowpass }
    p.to = o.to; p.toSec = o.toSec ?? 2
    return p
}

/// Plays `src` now, or after `delay` seconds of game time (frozen by pause, cancelled by leaving the scene).
private func start(_ src: Source, _ p: PlayParams, delay: Double) {
    if delay <= 0 { audio.play(src, p); return }
    delaySeq += 1
    let id = delaySeq
    let t = Task { @MainActor in
        do { try await wait(delay * 1000) } catch { return }
        delayed[id] = nil
        audio.play(src, p)
    }
    delayed[id] = (t, p.keep)
}

/// Tests set this to catch sounds that weren't loaded for the current chapter.
var onMissingSound: ((String) -> Void)? = nil

func play(_ name: String, _ list: [O] = []) {
    guard has(name) else { onMissingSound?(name); return }
    let o = Opts(list)
    start(.named(name), params(o), delay: o.delay ?? 0)
    if opts.haptics && (o.delay ?? 0) == 0 {
        if name == "knock" || name == "glassbang" { audio.haptic("knock") }
    }
}
func stopAll(_ includeKeep: Bool = false) {
    for (id, d) in delayed where includeKeep || !d.keep { d.task.cancel(); delayed[id] = nil }
    audio.stopAll(includeKeep: includeKeep)
}

func tone(_ list: [O]) {
    let o = Opts(list)
    let type = o.type ?? "sine", f = o.f ?? 440, f2 = o.f2, dur = o.dur ?? 0.2, gain = o.gain ?? 0.5, attack = o.attack ?? 0.01
    let key = "tone|\(type)|\(f)|\(f2 ?? 0)|\(dur)|\(gain)|\(attack)"
    var p = PlayParams()
    p.x = o.x ?? 0; p.y = o.y ?? 0; p.z = o.z ?? -1
    start(.synth(key) { Synth.tone(type: type, f: f, f2: f2, dur: dur, gain: gain, attack: attack) }, p, delay: o.delay ?? 0)
}

func uiClick() { tone([.f(160), .f2(70), .dur(0.12), .gain(0.25), .z(-0.6)]) }

func drip(_ x: Double) {
    tone([.f(1500), .f2(380), .dur(0.12), .gain(0.6), .x(x), .z(-0.5)])
    tone([.f(1400), .f2(360), .dur(0.12), .gain(0.15), .x(x), .z(-0.5), .delay(0.18)])
}

var heartBpm = 0.0
func heartbeat(_ bpm: Double) {
    let wasOn = heartBpm > 0
    heartBpm = bpm
    if bpm == 0 { heartStop(); return }
    if wasOn { return }
    loop("heart") {
        while heartBpm > 0 {
            if paused { try await sleepMs(300); continue }
            tone([.f(70), .f2(35), .dur(0.22), .gain(0.9), .z(0.01)])
            tone([.f(60), .f2(32), .dur(0.25), .gain(0.6), .z(0.01), .delay(0.24)])
            if opts.haptics { audio.haptic("heart") }
            try await sleepMs(60000 / heartBpm)
        }
    }
}
func heartStop() { heartBpm = 0; stopLoop("heart") }

func buzz(_ times: Double) {
    for i in upTo(times) {
        for k in [0.0, 0.5] {
            let t0 = i * 1.6 + k
            tone([.type("sawtooth"), .f(140), .dur(0.38), .gain(0.25), .attack(0.02), .x(0.6), .z(-0.4), .delay(t0)])
            tone([.type("square"), .f(70), .dur(0.38), .gain(0.12), .attack(0.02), .x(0.6), .z(-0.4), .delay(t0)])
        }
    }
    if opts.haptics { audio.haptic("buzz\(Int(times))") }
}

func whoosh(_ x: Double) {
    var p = PlayParams(); p.x = x; p.z = -2; p.to = [x, 0, 2]; p.toSec = 0.9
    audio.play(.synth("whoosh") {
        Synth.noiseBurst(1, kind: .bandpass, q: 1.2,
            freq: { t in t < 0.35 ? Synth.expRamp(300, 2500, t / 0.35) : Synth.expRamp(2500, 200, (t - 0.35) / 0.45) },
            gain: { t in t < 0.3 ? Synth.expRamp(0.0001, 1.2, t / 0.3) : Synth.expRamp(1.2, 0.0001, (t - 0.3) / 0.6) })
    }, p)
}

func boom() {
    tone([.f(80), .f2(25), .dur(2.2), .gain(1), .z(0.01)])
    for f in [466.0, 494, 523, 740] { tone([.type("sawtooth"), .f(f), .f2(f * 0.94), .dur(1.6), .gain(0.08), .z(-0.3)]) }
    if opts.haptics { audio.haptic("boom") }
}

func chime() {
    tone([.f(880), .dur(0.25), .gain(0.25), .x(0.5), .z(-0.5)])
    tone([.f(587), .dur(0.5), .gain(0.25), .x(0.5), .z(-0.5), .delay(0.22)])
}

func birds(_ on: Bool) {
    stopLoop("birds")
    if !on { return }
    loop("birds") {
        while true {
            if paused { try await sleepMs(300); continue }
            let x = Math.random() * 8 - 4, base = 2400 + Math.random() * 1600, n = 2 + Math.floor(Math.random() * 4)
            for i in upTo(n) { tone([.f(base), .f2(base * (1.3 + Math.random() * 0.4)), .dur(0.08), .gain(0.08), .x(x), .z(-6), .delay(i * 0.12)]) }
            try await sleepMs(500 + Math.random() * 1800)
        }
    }
}

/// repeated footstep sample, optionally travelling from one point to another
func steps(_ count: Double, _ list: [O] = []) {
    let o = Opts(list)
    let from = o.from ?? [0, 0, -3], to = o.to ?? from, gap = o.gap ?? 0.8
    for i in upTo(count) {
        let k = count > 1 ? i / (count - 1) : 0
        var l: [O] = [.x(from[0] + (to[0] - from[0]) * k), .y(from[1] + (to[1] - from[1]) * k), .z(from[2] + (to[2] - from[2]) * k),
                      .delay(i * gap), .rate((o.rate ?? 1) * (0.94 + Math.random() * 0.12)), .gain(o.gain ?? 1)]
        if let lp = o.lowpass { l.append(.lowpass(lp)) }
        play("steps", l)
    }
}
/// crunchy steps on gravel, travelling from one point to another
func gravel(_ count: Double, _ list: [O]) {
    let o = Opts(list)
    let from = o.from ?? [0, 0, 0], to = o.to ?? from, gap = o.gap ?? 0.55
    for i in upTo(count) {
        let k = count > 1 ? i / (count - 1) : 0
        play("gravel" + str(i % 3), [.x(from[0] + (to[0] - from[0]) * k), .z(from[2] + (to[2] - from[2]) * k), .delay(i * gap), .gain(o.gain ?? 1), .rate(0.9 + Math.random() * 0.2)])
    }
}
/// footsteps on concrete
func conc(_ count: Double, _ list: [O]) {
    let o = Opts(list)
    let from = o.from ?? [0, 0, 0], to = o.to ?? from, gap = o.gap ?? 0.55
    for i in upTo(count) {
        let k = count > 1 ? i / (count - 1) : 0
        play("conc" + str(i % 3), [.x(from[0] + (to[0] - from[0]) * k), .z(from[2] + (to[2] - from[2]) * k), .delay(i * gap), .gain(o.gain ?? 1), .rate(0.85 + Math.random() * 0.2)])
    }
}
/// something moving through the ceiling vents
func crawl(_ x: Double, _ dur: Double) {
    for i in upTo(dur / 450) {
        play(pick(["vent0", "vent1", "vent2"]), [.x(x + Math.random() * 0.6 - 0.3), .y(2.4), .z(-1.5 + i * 0.15), .delay(i * 0.45 + Math.random() * 0.15), .gain(0.9), .rate(0.6 + Math.random() * 0.3), .lowpass(2500)])
        if i % 3 == 0 { play("scratch", [.x(x), .y(2.4), .z(-1.2), .delay(i * 0.45), .gain(0.8), .rate(0.7), .lowpass(2500)]) }
    }
}

/* ---------- looping layers ---------- */

private func flat() -> PlayParams { var p = PlayParams(); p.spatial = false; p.loop = true; p.keep = true; return p }

func rain(_ level: Double, _ bright: Bool = false) {
    var p = flat(); p.highpass = 350; p.lowpass = 2500
    audio.setBed("rain", .named("rainloop"), p, gain: level, fade: 2)
    audio.setBedLowpass("rain", bright ? 7000 : 2500, fade: 1)
}
func engine(_ level: Double) {
    audio.setBed("engine", .synth("engine") { Synth.engineLoop() }, flat(), gain: level, fade: level > 0 ? 1.5 : 0.4)
}
func radio(_ level: Double) {
    var p = flat(); p.spatial = true; p.x = 0.5; p.z = -0.8
    audio.setBed("radio", .synth("radio") { Synth.noiseLoop(.bandpass, 1800, q: 0.7) }, p, gain: level, fade: 0.15)
}
func hum(_ level: Double) {
    audio.setBed("hum", .synth("hum") { Synth.humLoop() }, flat(), gain: level, fade: 1)
}
func wind(_ level: Double) {
    audio.setBed("wind", .synth("wind") { Synth.windLoop() }, flat(), gain: level, fade: 2)
}
func city(_ level: Double) {
    audio.setBed("city", .synth("city") { Synth.noiseLoop(.lowpass, 350) }, flat(), gain: level, fade: 2)
}
var fireLevel = 0.0
func fire(_ level: Double) {
    var p = flat(); p.spatial = true; p.x = 0.8; p.y = -0.3; p.z = -1.6
    audio.setBed("fire", .synth("fire") { Synth.noiseLoop(.lowpass, 700) }, p, gain: level * 0.25, fade: 2)
    fireLevel = level
    stopLoop("fire")
    if level == 0 { return }
    loop("fire") {
        while true {
            if !paused && fireLevel > 0 { tone([.type("square"), .f(1800 + Math.random() * 2500), .dur(0.015), .gain(0.05 * fireLevel), .x(0.8 + Math.random() * 0.3 - 0.15), .z(-1.6)]) }
            try await sleepMs(60 + Math.random() * 500)
        }
    }
}

func wipers(_ on: Bool) {
    stopLoop("wipers")
    if !on { return }
    loop("wipers") {
        while true {
            try await sleepMs(1300)
            if !paused { tone([.f(90), .f2(60), .dur(0.12), .gain(0.12), .z(-1.2)]) }
        }
    }
}

func ring(_ times: Double, _ x: Double, _ z: Double) {
    stopLoop("ring")
    loop("ring") {
        var n = 0.0
        while n < times {
            if !paused {
                n += 1
                var p = PlayParams(); p.x = x; p.z = z
                audio.play(.synth("ring") { Synth.ringBurst() }, p)
            }
            try await sleepMs(4000)
        }
    }
}
func ringStop() { stopLoop("ring") }

func bells(_ level: Double) {
    stopLoop("bells")
    if level == 0 { return }
    loop("bells") {
        var side = 1.0
        while true {
            if paused { try await sleepMs(300); continue }
            side = -side
            tone([.f(880), .dur(0.45), .gain(0.12 * level), .x(side * 3), .z(-12)])
            tone([.f(1320), .dur(0.3), .gain(0.05 * level), .x(side * 3), .z(-12)])
            try await sleepMs(560)
        }
    }
}
func pound(_ z: Double, _ gain: Double = 1) {
    stopLoop("pound")
    if z == 0 { return }
    loop("pound") {
        while true {
            if paused { try await sleepMs(300); continue }
            play(pick(["glassbang", "trunk"]), [.x(Math.random() * 2 - 1), .z(z), .gain(gain * (0.7 + Math.random() * 0.5)), .lowpass(3000), .rate(0.7 + Math.random() * 0.3)])
            try await sleepMs(300 + Math.random() * 900)
        }
    }
}
func monitor(_ on: Bool) {
    stopLoop("monitor")
    if !on { return }
    loop("monitor") {
        while true {
            if !paused { tone([.f(1000), .dur(0.09), .gain(0.05), .x(1.6), .z(-0.8)]) }
            try await sleepMs(1050)
        }
    }
}
func drips(_ on: Bool) {
    stopLoop("drips")
    if !on { return }
    loop("drips") {
        while true {
            if !paused {
                let x = Math.random() * 8 - 4
                tone([.f(1400 + Math.random() * 600), .f2(400), .dur(0.1), .gain(0.08), .x(x), .z(-3 - Math.random() * 5)])
                tone([.f(1300), .f2(380), .dur(0.1), .gain(0.03), .x(-x), .z(-6), .delay(0.25)])
            }
            try await sleepMs(700 + Math.random() * 1800)
        }
    }
}

/* ---------- one-shot effects ---------- */

func carDoor(_ x: Double) {
    tone([.f(130), .f2(40), .dur(0.35), .gain(1), .x(x), .z(-0.8)])
    tone([.type("square"), .f(300), .f2(90), .dur(0.08), .gain(0.15), .x(x), .z(-0.8)])
}
func skid() {
    var p = PlayParams(); p.spatial = false
    audio.play(.synth("skid") {
        Synth.noiseBurst(1.6, kind: .bandpass, q: 8,
            freq: { t in Synth.expRamp(1800, 700, t / 1.4) },
            gain: { t in t < 0.1 ? Synth.expRamp(0.0001, 0.9, t / 0.1) : Synth.expRamp(0.9, 0.0001, (t - 0.1) / 1.4) })
    }, p)
}
func scream() {
    boom()
    play("scream", [.gain(opts.soft ? 0.3 : 1.4), .z(-0.3)])
    play("scream", [.gain(opts.soft ? 0.15 : 0.7), .z(-0.3), .rate(0.82), .delay(0.05)])
    if opts.haptics { audio.haptic("scream") }
    view?.flash()
}
func shopChime(_ x: Double) {
    tone([.f(659), .dur(0.6), .gain(0.12), .x(x), .z(-7)])
    tone([.f(523), .dur(0.9), .gain(0.12), .x(x), .z(-7), .delay(0.35)])
}
func thunderSoon(_ ms: Double) { after(ms) { play("thunder", [.z(-8), .x(pick([-6, 6])), .gain(0.7)]) } }
func fob() {
    tone([.type("square"), .f(2200), .dur(0.09), .gain(0.08), .x(1), .z(3)])
    tone([.type("square"), .f(2200), .dur(0.09), .gain(0.08), .x(1), .z(3), .delay(0.16)])
}
func crash() {
    boom(); boom()
    play("glassbang", [.z(3), .gain(2.2), .rate(0.6)])
    for i in upTo(9) { play(pick(["trunk", "glassbang", "lock"]), [.x(Math.random() * 10 - 5), .z(3 + Math.random() * 6), .delay(0.05 + i * 0.09 + Math.random() * 0.1), .gain(1.8), .rate(0.4 + Math.random() * 0.5)]) }
    var p = PlayParams(); p.spatial = false
    audio.play(.synth("crash") {
        Synth.noiseBurst(2.6, kind: .lowpass, freq: { _ in 1800 }, gain: { t in Synth.expRamp(1.4, 0.0001, t / 2.5) })
    }, p)
}
func siren(_ dur: Double, _ from: [Double], _ to: [Double]) {
    var p = PlayParams(); p.x = from[0]; p.y = from[1]; p.z = from[2]; p.to = to; p.toSec = dur
    audio.play(.synth("siren\(dur)") { Synth.siren(dur) }, p)
}
func squelch(_ x: Double = 0.4, _ z: Double = -0.8) {
    var p = PlayParams(); p.x = x; p.z = z
    audio.play(.synth("squelch") {
        Synth.noiseBurst(0.25, kind: .bandpass, q: 1.5, freq: { _ in 2400 }, gain: { t in Synth.expRamp(0.35, 0.0001, t / 0.22) })
    }, p)
    tone([.type("square"), .f(1200), .dur(0.04), .gain(0.08), .x(x), .z(z)])
}
func buzzer() { tone([.type("square"), .f(120), .dur(0.6), .gain(0.12), .x(0), .z(-2.5)]) }
func owl() {
    tone([.f(420), .f2(360), .dur(0.5), .gain(0.08), .x(-6), .z(-10)])
    tone([.f(400), .f2(340), .dur(0.7), .gain(0.08), .x(-6), .z(-10), .delay(0.7)])
}

/// the creature playing a voice backwards
func playReversed(_ name: String, _ list: [O]) {
    guard let src = audio.pcm(name) else { return }
    let key = name + "_rev"
    if audio.pcm(key) == nil { audio.store(key, src.reversed()) }
    play(key, list)
}

@MainActor func say2(_ name: String, _ o: [O], _ extra: Double? = nil) async throws {
    play(name, o)
    try await wait(len(name) + (extra ?? 600))
}
func tapeClick() { tone([.type("square"), .f(180), .f2(90), .dur(0.06), .gain(0.25), .x(0.4), .z(-0.6)]) }
/// an old cassette: clunk, hiss, filtered voice
@MainActor func tape(_ name: String, _ extra: Double? = nil) async throws {
    tapeClick(); radio(0.035)
    try await wait(500)
    play(name, [.x(0.4), .z(-0.6), .phone(true), .gain(1.5)])
    try await wait(len(name) + (extra ?? 400))
    radio(0); tapeClick()
}

/// "hold still" scene: buttons that kill you, scripted sounds, then it moves on
func holdStill(_ title: String, _ text: String, _ traps: [(String, String)], _ events: [(Double, @MainActor () async throws -> Void)], _ doneMs: Double, _ next: @escaping @MainActor () async throws -> Void) {
    show(title, text, traps.map { t in Choice(t.0) { die(t.1) } })
    for (ms, fn) in events { after(ms, fn) }
    after(doneMs, next)
}

/* ---------- act four ---------- */
func speakerChime(_ x: Double, _ z: Double) {
    tone([.f(660), .dur(0.18), .gain(0.12), .x(x), .z(z)])
    tone([.f(990), .dur(0.3), .gain(0.12), .x(x), .z(z), .delay(0.15)])
}
func unplug(_ x: Double, _ z: Double) {
    play("unlock", [.x(x), .z(z), .gain(1.2)])
    tone([.f(900), .f2(120), .dur(0.6), .gain(0.12), .x(x), .z(z), .delay(0.1)])
}
/// our own take on a phone emergency alert: two harsh tones, pulsing, plus vibration
func emergencyAlert() {
    let g = opts.soft ? 0.08 : 0.22
    for i in upTo(4) { for f in [870.0, 990] { tone([.type("triangle"), .f(f), .dur(0.9), .gain(g), .attack(0.01), .x(i % 2 != 0 ? 0.5 : -0.5), .z(-0.4), .delay(i * 1.15)]) } }
    buzz(3)
}

/* ---------- switching things off ---------- */
func offCar() { radio(0); wipers(false); hum(0) }
func offCh4() { bells(0); pound(0) }
func offCh5() { wind(0); fire(0); ringStop() }
func offAct2() { monitor(false) }
func offAct4() { city(0) }
func silenceAll() {
    heartStop(); musicCut()
    rain(0); engine(0)
    offCar(); offCh4(); offCh5(); offAct2(); drips(false); offAct4()
}

/// a tape melting in the fire
func burnHiss() {
    var p = PlayParams(); p.spatial = false
    audio.play(.synth("burn") {
        Synth.noiseBurst(1.6, kind: .bandpass, freq: { _ in 900 }, gain: { t in Synth.expRamp(0.6, 0.0001, t / 1.5) })
    }, p)
}
