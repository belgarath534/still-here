import Foundation

// Last Stand: a zombie survival mode played with gestures instead of buttons.
// Zombies shuffle toward you down five lanes: far left, left, center, right, far right.
// Swipe left or right to move your aim one lane (a tone tells you which), tap to shoot,
// swipe down to reload, swipe up to hear how you're doing.

enum ZGesture { case turnLeft, turnRight, shoot, reload, status }

struct Zombie {
    var id: Int
    /// its lane, -2 (far left) to 2 (far right)
    var lane: Int
    var dist: Double
    var speed: Double
    var hp: Int
    var kind: String          // walker, runner, brute
    var nextSound: Double     // seconds until it groans or shuffles again
    var groanNext = true
    /// already warned that it's close
    var warned = false
}

let CLIP = 8
/// bites you can take
let MAXH = 5
var zZombies: [Zombie] = []
/// the lane you're aiming at, -2 to 2
var zAim = 0
var zAmmo = CLIP, zHealth = MAXH, zWave = 0, zKills = 0, zToSpawn = 0, zSpawnIn = 0.0
var zReloading = false, zRunning = false, zShots = 0, zHits = 0
var zSeq = 0
/// the training round: which step you're on, -1 when not training
var zTrain = -1
var zAimHelp: Bool {
    get { UserDefaults.standard.object(forKey: "stillhere-aimhelp") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-aimhelp") }
}
var bestWave: Int {
    get { UserDefaults.standard.integer(forKey: "stillhere-bestwave") }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-bestwave") }
}
/// turn the iPhone sideways for the fight
var zSideways: Bool {
    get { UserDefaults.standard.object(forKey: "stillhere-zsideways") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-zsideways") }
}
var zTrained: Bool {
    get { UserDefaults.standard.bool(forKey: "stillhere-ztrained") }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-ztrained") }
}

let Z_GROANS = 9
let Z_SFX = (0..<Z_GROANS).map { "z_groan\($0)" } + (0..<6).map { "z_step\($0)" } +
    ["z_shuffle0", "z_shuffle1", "z_shot0", "z_shot1", "z_reload", "z_die0", "z_die1", "z_bite", "z_click"]
var zStepIn = 0.0, zStepN = 0, zTickIn = 0.0
/// say where each new zombie is, and warn when one gets close
var zCallouts: Bool {
    get { UserDefaults.standard.object(forKey: "stillhere-zcallouts") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-zcallouts") }
}

/* ---------- the game's own voice ---------- */
// With a game voice on, players can mute VoiceOver (three-finger double-tap) during the fight and still
// hear everything: the game speaks its own callouts, warnings and status. Joe and Kristin are
// recorded clips (tools/make_voices.py); "iphone" uses the phone's own speech; "voiceover" speaks
// through VoiceOver, as before.

let ZVOICES = ["joe", "kristin", "iphone", "voiceover"]
let ZVOICE_NAMES = ["joe": "Joe", "kristin": "Kristin", "iphone": "the iPhone's own voice", "voiceover": "VoiceOver only"]
var zVoice: String {
    get { UserDefaults.standard.string(forKey: "stillhere-zvoice").flatMap { ZVOICES.contains($0) ? $0 : nil } ?? "joe" }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-zvoice") }
}
/// the iPhone's own voice; the app plugs it in. `urgent` cuts off whatever it was saying.
var onSpeak: ((String, Bool) -> Void)? = nil
/// every line a recorded voice knows (tools/zvoice_phrases.json)
let ZV_KEYS: [String] = ["farleft", "left", "center", "right", "farright"].flatMap { ["new_" + $0, "close_" + $0, "lane_" + $0] }
    + (0...60).map { "n\($0)" }
    + ["bullets", "bullet", "hitsleft", "hitleft", "wave", "zombiesleft", "zombieleft", "aiming", "nearest", "veryclose", "close", "far",
       "ofthem", "cleared", "empty", "emptyshort", "full", "bitten", "overrun", "intro1", "intro2", "intro4", "intro5", "listen",
       "tip_mute", "tip_unmute", "hello", "train0", "train1", "train2", "train3", "train4", "traindone"]
func zvRecorded(_ v: String) -> Bool { v == "joe" || v == "kristin" }
func zvClips(_ v: String) -> [String] { zvRecorded(v) ? ZV_KEYS.map { "zv_\(v)_\($0)" } : [] }
let LANE_KEYS = ["farleft", "left", "center", "right", "farright"]
func zN(_ n: Int) -> String { "n\(Swift.min(Swift.max(n, 0), 60))" }

private var zvQueue: [String] = []
private var zvPlaying = false
/// whether the player has heard the "mute VoiceOver" tip in this visit to Last Stand
var zTipGiven = false
/// the app tells us whether VoiceOver is running; tests leave it off
var isVoiceOverRunning: () -> Bool = { false }
/// the "you can mute VoiceOver" alert, shown once each time the app is opened
var zAlertShown = false
let Z_VO_TIP = "Tip: Last Stand speaks for itself. To hear the fight clearly, mute VoiceOver's speech with a three-finger double-tap, or turn VoiceOver off. Your swipes and taps work either way. When the fight ends, three-finger double-tap again to bring VoiceOver back."

/// Before a fight: with a game voice and VoiceOver on, a real alert explains muting VoiceOver, once per app launch.
@MainActor func zWithTip(_ next: @escaping @MainActor () -> Void) {
    if zVoice != "voiceover" && isVoiceOverRunning() && !zAlertShown, let v = view {
        zAlertShown = true
        v.contentNote(Z_VO_TIP) { Task { @MainActor in next() } }
    } else { next() }
}

/// Says something in the chosen voice. `keys` are recorded clips joined together; `text` is the same in words.
func zSpeak(_ keys: [String], _ text: String, urgent: Bool = false) {
    let v = zVoice
    if v == "voiceover" { say(text); return }
    if v == "iphone" { if let f = onSpeak { f(text, urgent) } else { say(text) }; return }
    if urgent { zvQueue.removeAll() }
    zvQueue += keys.map { "zv_\(v)_\($0)" }
    guard !zvPlaying else { return }
    zvPlaying = true
    spawn {
        defer { zvPlaying = false }
        while !zvQueue.isEmpty {
            let c = zvQueue.removeFirst()
            play(c, [.z(-0.5), .gain(1.5)])
            try await wait(len(c) + 30)
        }
    }
}
/// how long a line will take to say, so sounds can wait for it
func zSpeakLength(_ keys: [String]) -> Double { zvRecorded(zVoice) ? keys.reduce(0) { $0 + len("zv_\(zVoice)_\($1)") + 30 } : 0 }

/* ---------- where things are ---------- */

/// how many lanes to the right of your aim it is (negative: to the left)
func zRel(_ z: Zombie) -> Int { z.lane - zAim }
/// where a lane is: spread across the front, 30 degrees apart. Zombies, the aim note and the
/// aim tick all use this, so a lane always sounds in the same place.
private func place(lane: Int, _ dist: Double) -> [O] {
    let a = Double(lane) * 30 * Double.pi / 180
    let d = Swift.max(dist, 0.6)
    return [.x(sin(a) * d), .z(-cos(a) * d)]
}
let LANES = ["far left", "left", "center", "right", "far right"]
func zLaneName(_ lane: Int) -> String { LANES[lane + 2] }
func zDistName(_ d: Double) -> String { d < 2 ? "very close" : d < 4.5 ? "close" : "far" }

private func zSound(_ z: inout Zombie) {
    let rate = z.kind == "brute" ? 0.8 : z.kind == "runner" ? 1.15 : 0.92 + Math.random() * 0.14
    let near = z.dist < 3
    if z.groanNext || near {
        play("z_groan" + str(Int(Math.random() * Double(Z_GROANS))), place(lane: z.lane, z.dist) + [.rate(rate), .gain(z.kind == "brute" ? 2.3 : 2.0)])
    } else {
        play("z_shuffle" + str(Int(Math.random() * 2)), place(lane: z.lane, z.dist) + [.rate(rate), .gain(1.6)])
    }
    z.groanNext.toggle()
    z.nextSound = (near ? 0.7 : 1.1) + Math.random() * 0.6
}

/* ---------- the fight ---------- */

private func waveSize(_ w: Int = zWave) -> Int { 4 + (w - 1) * 2 }
/// wave 1: one at a time; then a second, third and fourth join in slowly
private func maxAtOnce() -> Int { Swift.min(1 + zWave / 2, 4) }
private func speedScale() -> Double { (opts.extraTime ? 0.75 : 1) * (opts.hard ? 1.2 : 1) }

private func spawnZombie() {
    zSeq += 1
    // a free lane if there is one
    let used = Set(zZombies.map(\.lane))
    let free = (-2...2).filter { !used.contains($0) }
    let lane = pick(free.isEmpty ? Array(-2...2) : free)
    var kind = "walker"
    if zWave >= 5 && Math.random() < 0.25 { kind = "runner" }
    if zWave >= 4 && Math.random() < 0.2 { kind = "brute" }
    let base = Swift.min(0.27 + Double(zWave) * 0.04, 0.8)
    let speed = base * (kind == "runner" ? 1.6 : kind == "brute" ? 0.7 : 1) * speedScale()
    var z = Zombie(id: zSeq, lane: lane, dist: 8 + Math.random() * 1.5, speed: speed, hp: kind == "brute" ? 2 : 1, kind: kind, nextSound: 0)
    zSound(&z)
    zZombies.append(z)
    zToSpawn -= 1
    // early on, say where each new one is, so you learn what the lanes sound like
    if zCallouts { zSpeak(["new_" + LANE_KEYS[lane + 2]], "Zombie, " + zLaneName(lane) + ".") }
}

/// One tenth of a second of the fight.
func zTick(_ dt: Double) {
    if zTrain < 0 && zToSpawn > 0 && zZombies.count < maxAtOnce() {
        zSpawnIn -= dt
        if zSpawnIn <= 0 {
            spawnZombie()
            zSpawnIn = Swift.max(5 - Double(zWave) * 0.4, 2) + Math.random()
        }
    }
    // your own footsteps, under you
    if zTrain < 0 {
        zStepIn -= dt
        if zStepIn <= 0 {
            zStepN += 1
            play("z_step" + str(Int(Math.random() * 6)), [.x(zStepN % 2 == 0 ? -0.15 : 0.15), .y(-1.4), .z(0), .gain(0.4), .rate(0.95 + Math.random() * 0.1)])
            zStepIn = 0.62
        }
    }
    // aim helper: a soft tick, over and over, while one is in the lane you're aiming at
    if zAimHelp {
        zTickIn -= dt
        if zTickIn <= 0 {
            zTickIn = 0.7
            if zZombies.contains(where: { zRel($0) == 0 }) {
                tone([.type("sine"), .f(1400), .dur(0.04), .gain(0.15)] + place(lane: zAim, 1.5))
            }
        }
    }
    for i in zZombies.indices {
        zZombies[i].dist -= zZombies[i].speed * dt
        if zCallouts && !zZombies[i].warned && zZombies[i].dist < 3 && zTrain < 0 {
            zZombies[i].warned = true
            zSpeak(["close_" + LANE_KEYS[zZombies[i].lane + 2]], "Close, " + zLaneName(zZombies[i].lane) + "!", urgent: true)
        }
        zZombies[i].nextSound -= dt
        if zZombies[i].nextSound <= 0 { zSound(&zZombies[i]) }
    }
    if let i = zZombies.firstIndex(where: { $0.dist <= 0.9 }) { zBitten(i) }
}

private func zBitten(_ i: Int) {
    let z = zZombies[i]
    play("z_bite", place(lane: z.lane, 0.6) + [.gain(1.6)])
    audio.haptic("boom")
    view?.flash()
    zHealth -= 1
    // you shove it away; it comes back
    zZombies[i].dist = 5
    zZombies[i].warned = false
    zZombies[i].nextSound = 1.5
    if zHealth <= 0 { zDie(); return }
    zSpeak(["bitten", zN(zHealth), zHealth == 1 ? "hitleft" : "hitsleft"], zHealth == 1 ? "Bitten. One hit left." : "Bitten. " + str(zHealth) + " hits left.", urgent: true)
    zStatusText()
}

func zGesture(_ g: ZGesture) {
    guard !paused else { return }
    // resting between waves (with a game voice): tap for the next wave, swipe up to hear how you're doing
    if zResting {
        if g == .shoot { zResting = false; if zTrain == -2 { zTrain = -1; zNewRun() } else { zStartWave() } }
        if g == .status { zSpeak(zStatusKeys(), zStatusLine(full: false), urgent: true) }
        return
    }
    guard zRunning else { return }
    switch g {
    case .turnLeft, .turnRight:
        let next = zAim + (g == .turnRight ? 1 : -1)
        if next < -2 || next > 2 {
            // already at the edge
            tone([.type("square"), .f(110), .dur(0.08), .gain(0.14)] + place(lane: zAim, 1.5))
            return
        }
        zAim = next
        // each lane has its own note, low on the left, high on the right, played from that side
        tone([.type("triangle"), .f([262, 330, 392, 494, 587][zAim + 2]), .dur(0.08), .gain(0.2)] + place(lane: zAim, 1.5))
        if zAimHelp, let z = zZombies.filter({ zRel($0) == 0 }).min(by: { $0.dist < $1.dist }) {
            // a soft tick when one is right in front of you
            tone([.type("sine"), .f(1400), .dur(0.04), .gain(0.15), .delay(0.07)] + place(lane: zAim, 1.5))
            var copy = z
            zSound(&copy)
            if let i = zZombies.firstIndex(where: { $0.id == z.id }) { zZombies[i].nextSound = copy.nextSound; zZombies[i].groanNext = copy.groanNext }
        }
    case .shoot: zShoot()
    case .reload: zReload()
    case .status:
        zSpeak(zStatusKeys(), zStatusLine(full: true), urgent: true)
        if zTrain == 4 { zTrainNext() }
    }
}

private func zShoot() {
    if zReloading { return }
    if zAmmo == 0 {
        play("z_click", [.z(-0.4), .gain(1.4)])
        zSpeak(["empty"], "Empty. Swipe down to reload.", urgent: true)
        return
    }
    zAmmo -= 1
    zShots += 1
    play("z_shot" + str(zShots % 2), [.z(-0.5), .gain(1.3)])
    audio.haptic("knock")
    let ahead = zZombies.filter { zRel($0) == 0 }.sorted { $0.dist < $1.dist }
    if var z = ahead.first, let i = zZombies.firstIndex(where: { $0.id == z.id }) {
        zHits += 1
        z.hp -= 1
        if z.hp <= 0 {
            zZombies.remove(at: i)
            zKills += 1
            play("z_die" + str(Int(Math.random() * 2)), place(lane: z.lane, z.dist) + [.delay(0.12), .gain(1.4), .rate(z.kind == "brute" ? 0.85 : 1)])
            zAfterKill()
        } else {
            zZombies[i] = z
            zZombies[i].dist += 1.2   // it staggers back
            play("z_groan" + str(Int(Math.random() * Double(Z_GROANS))), place(lane: z.lane, z.dist + 1.2) + [.delay(0.15), .rate(0.75), .gain(1.6)])
        }
    }
    if zAmmo == 0 { after(400) { if zRunning && zAmmo == 0 && !zReloading { zSpeak(["emptyshort"], "Empty.") } } }
    zStatusText()
}

private func zReload() {
    if zReloading || zAmmo == CLIP { if zAmmo == CLIP { zSpeak(["full"], "Already full.") }; return }
    zReloading = true
    play("z_reload", [.x(0.2), .z(-0.4), .gain(1.4)])
    after(1500) {
        zAmmo = CLIP
        zReloading = false
        zStatusText()
        if zTrain == 1 { zTrainNext() }
    }
}

func zStatusLine(full: Bool) -> String {
    var s = str(zAmmo) + (zAmmo == 1 ? " bullet" : " bullets") + ", " + str(zHealth) + (zHealth == 1 ? " hit" : " hits") + " left."
    if zTrain < 0 {
        let left = zToSpawn + zZombies.count
        s += " Wave " + str(zWave) + ", " + str(left) + (left == 1 ? " zombie" : " zombies") + " left."
    }
    if full {
        s += " Aiming " + zLaneName(zAim) + "."
        if let z = zZombies.min(by: { $0.dist < $1.dist }) { s += " Nearest: " + zLaneName(z.lane) + ", " + zDistName(z.dist) + "." }
    }
    return s
}
/// The status line as recorded clips: "Seven bullets. Four hits left. Wave three. Five zombies left. Aiming center. Nearest: left, close."
func zStatusKeys() -> [String] {
    var k = [zN(zAmmo), zAmmo == 1 ? "bullet" : "bullets", zN(zHealth), zHealth == 1 ? "hitleft" : "hitsleft"]
    if zTrain < 0 {
        let left = zToSpawn + zZombies.count
        k += ["wave", zN(zWave), zN(left), left == 1 ? "zombieleft" : "zombiesleft"]
    }
    k += ["aiming", "lane_" + LANE_KEYS[zAim + 2]]
    if let z = zZombies.min(by: { $0.dist < $1.dist }) { k += ["nearest", "lane_" + LANE_KEYS[z.lane + 2], z.dist < 2 ? "veryclose" : z.dist < 4.5 ? "close" : "far"] }
    return k
}

/// Updates the words on screen without moving VoiceOver.
private func zStatusText() {
    guard zRunning, screen.panel == .arena else { return }
    screen.text = zStatusLine(full: false)
    render()
}

private func zAfterKill() {
    if zTrain >= 0 { zTrainNext(); return }
    if zToSpawn == 0 && zZombies.isEmpty { zWaveCleared() }
}

/* ---------- waves ---------- */

private let HOWTO = "You walk forward on your own. Zombies come at you down five lanes: far left, left, center, right and far right. Swipe left or right to move your aim one lane; a note tells you where you're aiming, low on the left and high on the right. Tap to shoot. Swipe down to reload. Swipe up to hear your bullets, health and where they are. Two fingers double-tap to pause."

/// tap-to-continue between waves, when a game voice is on (VoiceOver may be muted, so no buttons)
var zResting = false

private func arena(_ title: String, _ intro: String, _ keys: [String]) {
    screen.landscape = zSideways
    // the same fight area stays on screen between waves, so VoiceOver doesn't re-announce it every time
    if screen.panel == .arena { screen.title = title; screen.text = intro; render() }
    else { show(title, intro, [], .arena) }
    screen.mode = .game
    screen.text = zStatusLine(full: false)
    render()
    var k = keys
    if !zTipGiven && zVoice != "voiceover" { zTipGiven = true; k = ["tip_mute"] + k }
    zSpeak(k, intro, urgent: true)
}

private func zStartWave() {
    zWave += 1
    zZombies = []
    zToSpawn = waveSize()
    zSpawnIn = 2.5
    zAmmo = CLIP
    zReloading = false
    zRunning = true
    music(zWave >= 4 ? "m_zfight2" : "m_zfight", 0.2, 3)
    wind(0.05)
    zStepIn = 1
    let introKey = zWave == 1 ? "intro1" : zWave == 2 ? "intro2" : zWave == 4 ? "intro4" : zWave == 5 ? "intro5" : "listen"
    arena("Wave " + str(zWave), "Wave " + str(zWave) + ". " + str(waveSize()) + " of them. " + (zWave == 1 ? "One at a time. You're aiming at the center lane." : zWave == 2 ? "Now two at once." : zWave == 4 ? "Watch for big ones. They take two shots." : zWave == 5 ? "Some of them run." : "Listen."),
          ["wave", zN(zWave), zN(waveSize()), "ofthem", introKey])
    spawn {
        while zRunning {
            try await wait(100)
            if zRunning { zTick(0.1) }
        }
    }
}

private func zWaveCleared() {
    zRunning = false
    clearScene()
    if zWave > bestWave { bestWave = zWave }
    music("m_zrest", 0.22, 3)
    let healed = zHealth < MAXH
    zHealth = Swift.min(zHealth + 1, MAXH)
    chime()
    let text = "Silence. For now." + (healed ? " You catch your breath: " + str(zHealth) + " hits left." : "") + "\n\nWave " + str(zWave + 1) + " brings " + str(waveSize(zWave + 1)) + " of them, a little faster."
    if zVoice != "voiceover" {
        // VoiceOver may be muted: stay in the fight area and let a tap start the next wave
        zResting = true
        screen.title = "Wave " + str(zWave) + " cleared"
        screen.text = text + "\n\nTap to start the next wave. Swipe up to hear how you're doing."
        render()
        zSpeak(["wave", zN(zWave), "cleared", zN(zHealth), zHealth == 1 ? "hitleft" : "hitsleft"], screen.text, urgent: true)
        return
    }
    show("Wave " + str(zWave) + " cleared", text, [
        Choice("Next wave") { zStartWave() },
        Choice("Main menu", to("title")),
    ])
}

private func zDie() {
    zRunning = false
    clearScene()
    silenceAll()
    zResting = false
    show("", "", [])
    scream()
    after(2600) {
        music("m_zrest", 0.22, 3)
        // the end of the fight: back to buttons, so the player gets VoiceOver back
        if zVoice != "voiceover" { zTipGiven = false; zSpeak(["overrun", "tip_unmute"], "Overrun. Three-finger double-tap to bring VoiceOver back.", urgent: true) }
        let cleared = zWave - 1
        let record = cleared > bestWave
        if record { bestWave = cleared }
        let acc = zShots > 0 ? " You hit " + str(Int((Double(zHits) / Double(zShots) * 100).rounded())) + " percent of your shots." : ""
        show("Overrun", "They got you in wave " + str(zWave) + ". You took down " + str(zKills) + (zKills == 1 ? " zombie." : " zombies.") + acc + (record && cleared > 0 ? "\n\nThat's your best yet." : bestWave > 0 ? "\n\nYour best: " + str(bestWave) + (bestWave == 1 ? " wave." : " waves.") : ""), [
            Choice("Try again") { zNewRun() },
            Choice("Main menu", to("title")),
        ])
    }
}

func zNewRun() {
    zResting = false
    zWave = 0; zKills = 0; zHealth = MAXH; zShots = 0; zHits = 0; zAim = 0; zTrain = -1
    zStartWave()
}

/* ---------- training ---------- */

private let TRAIN: [String] = [
    "Training. There are five lanes in front of you. Listen: here they are, from far left to far right. You're aiming at the center one. A zombie is coming into the center lane, chained to a post. It can't reach you. Tap to shoot it.",
    "Got it. Your gun holds eight bullets. Swipe down to reload. Try it now.",
    "Good. The next one is in the far right lane. Swipe right twice: each swipe plays a higher note. You'll hear a soft tick when you're aiming at it. Then tap.",
    "Now one in the left lane. Swipe left until you hear ticking: it ticks for as long as you're aimed at one. Then tap.",
    "Last thing. Swipe up any time to hear your bullets, your health, which lane you're aiming at and where the nearest one is. Try it.",
]

private func zTrainSpawn(_ lane: Int) {
    zSeq += 1
    var z = Zombie(id: zSeq, lane: lane, dist: 5, speed: 0, hp: 1, kind: "walker", nextSound: 0)
    zSound(&z)
    zZombies = [z]
}

private func zTrainShow() {
    let step = zTrain
    arena("Training", TRAIN[step], ["train\(step)"])
    if step == 0 {
        // the five lanes, far left to far right, each from where its zombies will be (after the voice has said so)
        let start = zSpeakLength((zTipGiven && zVoice != "voiceover" ? ["tip_mute"] : []) + ["train0"]) / 1000 + 0.6
        for l in -2...2 {
            tone([.type("triangle"), .f([262, 330, 392, 494, 587][l + 2]), .dur(0.12), .gain(0.2), .delay(start + Double(l + 2) * 0.55)] + place(lane: l, 1.5))
        }
        after(start * 1000 + 3400) { if zTrain == 0 { zTrainSpawn(0) } }
    }
    if step == 2 { zTrainSpawn(2) }
    if step == 3 { zTrainSpawn(-1) }
}

private func zTrainNext() {
    zTrain += 1
    if zTrain >= TRAIN.count {
        zRunning = false
        zTrain = -1
        zTrained = true
        clearScene()
        chime()
        if zVoice != "voiceover" {
            // VoiceOver may be muted: stay in the fight area, tap to start the real fight
            zResting = true
            zTrain = -2
            screen.title = "Training done"
            screen.text = "That's everything. Tap to start the fight."
            render()
            zSpeak(["traindone"], "That's everything. Start the fight when you're ready. Tap to start.", urgent: true)
            return
        }
        show("Training done", "That's everything. In a real fight they keep coming, more at once each wave, and if one reaches you it bites. Five bites and it's over; you get one back after every wave you clear.\n\nTwo fingers double-tap pauses the fight at any time.", [
            Choice("Start the fight") { zNewRun() },
            Choice("Back", to("x_start")),
        ])
        return
    }
    after(zTrain == 1 ? 1200 : 600) { zTrainShow() }
}

/// Switches to the next voice, loads its clips, and plays a sample of it.
@MainActor func zNextVoice() async {
    let old = zVoice
    let next = ZVOICES[(ZVOICES.firstIndex(of: old)! + 1) % ZVOICES.count]
    if zvRecorded(next) { _ = await audio.load(zvClips(next)) }
    if zvRecorded(old) { audio.unload(zvClips(old)) }
    zVoice = next
    go("x_start")
    switch next {
    case "voiceover": say("VoiceOver only. The game speaks through VoiceOver, as before.")
    case "iphone": if let f = onSpeak { f("This is the voice you'll hear in Last Stand. Zombie, far left.", true) }
    default: zSpeak(["hello"], "This is the voice you'll hear in Last Stand.", urgent: true)
    }
}

/* ---------- scenes ---------- */

func registerZombies() {
    scene("x_start") {
        silenceAll()
        zRunning = false
        zResting = false
        zTipGiven = false
        var choices = [Choice("Start the fight") { zWithTip { zNewRun() } }, Choice("Training") { zWithTip { go("x_train") } }]
        if !zTrained { choices.swapAt(0, 1) }
        choices += [
            Choice("Aim helper, ticking while you're aimed at one: " + (zAimHelp ? "on" : "off")) { zAimHelp.toggle(); go("x_start") },
            Choice("Call out where they are: " + (zCallouts ? "on" : "off")) { zCallouts.toggle(); go("x_start") },
            Choice("Turn the phone sideways for the fight: " + (zSideways ? "on" : "off")) { zSideways.toggle(); go("x_start") },
            Choice("Game voice: " + (ZVOICE_NAMES[zVoice] ?? zVoice) + ". Double-tap to switch and hear it") { await zNextVoice() },
            Choice("Back", to("title")),
        ]
        show("Last Stand", "You, a pistol, and the dark. They come in waves. You'll only hear them.\n\n" + HOWTO + "\n\nThe game can talk for itself during the fight: pick a game voice below, then mute VoiceOver with a three-finger double-tap when the fight starts." + (zTrained ? "" : "\n\nNew here? Start with the training.") + (bestWave > 0 ? "\n\nYour best: " + str(bestWave) + (bestWave == 1 ? " wave." : " waves.") : ""), choices)
    }
    scene("x_train") {
        zResting = false
        zWave = 0; zHealth = MAXH; zAmmo = CLIP; zAim = 0; zReloading = false; zZombies = []
        zTrain = 0
        zRunning = true
        wind(0.04)
        zTrainShow()
        spawn {
            while zRunning {
                try await wait(100)
                if zRunning { zTick(0.1) }
            }
        }
    }
}
