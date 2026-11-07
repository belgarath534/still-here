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
var zStepIn = 0.0, zStepN = 0

/* ---------- where things are ---------- */

/// how many lanes to the right of your aim it is (negative: to the left)
func zRel(_ z: Zombie) -> Int { z.lane - zAim }
/// where a lane is: spread across the front, 40 degrees apart
private func place(lane: Int, _ dist: Double) -> [O] {
    let a = Double(lane) * 40 * Double.pi / 180
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
    if zWave <= 2 { say("Zombie, " + zLaneName(lane) + ".") }
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
    for i in zZombies.indices {
        zZombies[i].dist -= zZombies[i].speed * dt
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
    zZombies[i].nextSound = 1.5
    if zHealth <= 0 { zDie(); return }
    say(zHealth == 1 ? "Bitten. One hit left." : "Bitten. " + str(zHealth) + " hits left.")
    zStatusText()
}

func zGesture(_ g: ZGesture) {
    guard zRunning, !paused else { return }
    switch g {
    case .turnLeft, .turnRight:
        let next = zAim + (g == .turnRight ? 1 : -1)
        if next < -2 || next > 2 {
            // already at the edge
            tone([.type("square"), .f(110), .dur(0.08), .gain(0.12), .x(Double(zAim) * 0.4), .z(-0.8)])
            return
        }
        zAim = next
        // each lane has its own note, low on the left, high on the right, played from that side
        tone([.type("triangle"), .f([262, 330, 392, 494, 587][zAim + 2]), .dur(0.08), .gain(0.16), .x(Double(zAim) * 0.45), .z(-0.8)])
        if zAimHelp, let z = zZombies.filter({ zRel($0) == 0 }).min(by: { $0.dist < $1.dist }) {
            // a soft tick when one is right in front of you
            tone([.type("sine"), .f(1400), .dur(0.04), .gain(0.12), .z(-0.5), .delay(0.07)])
            var copy = z
            zSound(&copy)
            if let i = zZombies.firstIndex(where: { $0.id == z.id }) { zZombies[i].nextSound = copy.nextSound; zZombies[i].groanNext = copy.groanNext }
        }
    case .shoot: zShoot()
    case .reload: zReload()
    case .status:
        say(zStatusLine(full: true))
        if zTrain == 4 { zTrainNext() }
    }
}

private func zShoot() {
    if zReloading { return }
    if zAmmo == 0 {
        play("z_click", [.z(-0.4), .gain(1.4)])
        say("Empty. Swipe down to reload.")
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
    if zAmmo == 0 { after(400) { if zRunning && zAmmo == 0 && !zReloading { say("Empty.") } } }
    zStatusText()
}

private func zReload() {
    if zReloading || zAmmo == CLIP { if zAmmo == CLIP { say("Already full.") }; return }
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

private func arena(_ title: String, _ intro: String) {
    screen.landscape = zSideways
    show(title, intro, [], .arena)
    screen.mode = .game
    screen.text = zStatusLine(full: false)
    render()
    say(intro)
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
    arena("Wave " + str(zWave), "Wave " + str(zWave) + ". " + str(waveSize()) + " of them. " + (zWave == 1 ? "One at a time. You're aiming at the center lane." : zWave == 2 ? "Now two at once." : zWave == 4 ? "Watch for big ones. They take two shots." : zWave == 5 ? "Some of them run." : "Listen."))
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
    show("Wave " + str(zWave) + " cleared", "Silence. For now." + (healed ? " You catch your breath: " + str(zHealth) + " hits left." : "") + "\n\nWave " + str(zWave + 1) + " brings " + str(waveSize(zWave + 1)) + " of them, a little faster.", [
        Choice("Next wave") { zStartWave() },
        Choice("Main menu", to("title")),
    ])
}

private func zDie() {
    zRunning = false
    clearScene()
    silenceAll()
    show("", "", [])
    scream()
    after(2600) {
        music("m_zrest", 0.22, 3)
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
    zWave = 0; zKills = 0; zHealth = MAXH; zShots = 0; zHits = 0; zAim = 0; zTrain = -1
    zStartWave()
}

/* ---------- training ---------- */

private let TRAIN: [String] = [
    "Training. There are five lanes in front of you, and you're aiming at the center one. A zombie is in the center lane, chained to a post. It can't reach you. Tap to shoot it.",
    "Got it. Your gun holds eight bullets. Swipe down to reload. Try it now.",
    "Good. The next one is in the far right lane. Swipe right twice: each swipe plays a higher note. You'll hear a soft tick when you're aiming at it. Then tap.",
    "Now one in the left lane. Swipe left until you hear the tick, then tap.",
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
    arena("Training", TRAIN[step])
    if step == 0 { zTrainSpawn(0) }
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
        show("Training done", "That's everything. In a real fight they keep coming, more at once each wave, and if one reaches you it bites. Five bites and it's over; you get one back after every wave you clear.\n\nTwo fingers double-tap pauses the fight at any time.", [
            Choice("Start the fight") { zNewRun() },
            Choice("Back", to("x_start")),
        ])
        return
    }
    after(zTrain == 1 ? 1200 : 600) { zTrainShow() }
}

/* ---------- scenes ---------- */

func registerZombies() {
    scene("x_start") {
        silenceAll()
        zRunning = false
        var choices = [Choice("Start the fight") { zNewRun() }, Choice("Training") { go("x_train") }]
        if !zTrained { choices.swapAt(0, 1) }
        choices += [
            Choice("Aim helper: " + (zAimHelp ? "on" : "off")) { zAimHelp.toggle(); go("x_start") },
            Choice("Turn the screen when you hold the phone sideways: " + (zSideways ? "on" : "off")) { zSideways.toggle(); go("x_start") },
            Choice("Back", to("title")),
        ]
        show("Last Stand", "You, a pistol, and the dark. They come in waves. You'll only hear them.\n\n" + HOWTO + (zTrained ? "" : "\n\nNew here? Start with the training.") + (bestWave > 0 ? "\n\nYour best: " + str(bestWave) + (bestWave == 1 ? " wave." : " waves.") : ""), choices)
    }
    scene("x_train") {
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
