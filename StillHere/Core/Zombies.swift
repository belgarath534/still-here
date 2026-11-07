import Foundation

// Last Stand: a zombie survival mode played with gestures instead of buttons.
// Zombies shuffle toward you from all around. Swipe left or right to turn until the groaning is
// in the middle of your head, tap to shoot, swipe down to reload, swipe up to hear how you're doing.
// Directions come in eight steps of 45 degrees, so "in the middle" is something you can hear.

enum ZGesture { case turnLeft, turnRight, shoot, reload, status }

struct Zombie {
    var id: Int
    /// which of the eight directions it's in, 0 to 7, fixed in the world (0 is where you faced at the start)
    var dir: Int
    var dist: Double
    var speed: Double
    var hp: Int
    var kind: String          // walker, runner, brute
    var nextSound: Double     // seconds until it groans or shuffles again
    var groanNext = true
}

let CLIP = 8
var zZombies: [Zombie] = []
var zAim = 0
var zAmmo = CLIP, zHealth = 3, zWave = 0, zKills = 0, zToSpawn = 0, zSpawnIn = 0.0
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
/// You keep walking on your own, toward wherever you face. Metres per second.
let WALK = 0.25
var zStepIn = 0.0, zStepN = 0

/* ---------- where things are ---------- */

/// -4...3: 0 is straight ahead, positive to your right, 4 (shown as -4) behind you
func zRel(_ z: Zombie) -> Int { ((z.dir - zAim) % 8 + 12) % 8 - 4 }
private func place(_ rel: Int, _ dist: Double) -> [O] {
    let a = Double(rel) * Double.pi / 4
    let d = Swift.max(dist, 0.6)
    return [.x(sin(a) * d), .z(-cos(a) * d)]
}
func zDirName(_ rel: Int) -> String {
    ["behind you", "behind you on the left", "on your left", "ahead on your left", "straight ahead", "ahead on your right", "on your right", "behind you on the right"][rel + 4]
}
func zDistName(_ d: Double) -> String { d < 2.5 ? "very close" : d < 5 ? "close" : "far" }

private func zSound(_ z: inout Zombie) {
    let rate = z.kind == "brute" ? 0.8 : z.kind == "runner" ? 1.15 : 0.92 + Math.random() * 0.14
    let near = z.dist < 3
    if z.groanNext || near {
        play("z_groan" + str(Int(Math.random() * Double(Z_GROANS))), place(zRel(z), z.dist) + [.rate(rate), .gain(z.kind == "brute" ? 1.6 : 1.3)])
    } else {
        play("z_shuffle" + str(Int(Math.random() * 2)), place(zRel(z), z.dist) + [.rate(rate), .gain(1.1)])
    }
    z.groanNext.toggle()
    z.nextSound = (near ? 0.7 : 1.1) + Math.random() * 0.6
}

/* ---------- the fight ---------- */

private func waveSize() -> Int { 4 + zWave * 2 }
private func maxAtOnce() -> Int { Swift.min(1 + (zWave + 1) / 2, 5) }
private func speedScale() -> Double { (opts.extraTime ? 0.75 : 1) * (opts.hard ? 1.2 : 1) }

private func spawnZombie() {
    zSeq += 1
    // early waves come from in front and the sides; later ones from anywhere
    let rel = zWave < 3 ? pick([-2, -1, 0, 1, 2]) : pick([-4, -3, -2, -1, 0, 1, 2, 3])
    var kind = "walker"
    if zWave >= 4 && Math.random() < 0.25 { kind = "runner" }
    if zWave >= 3 && Math.random() < 0.2 { kind = "brute" }
    let base = Swift.min(0.55 + Double(zWave) * 0.06, 1.2)
    let speed = base * (kind == "runner" ? 1.6 : kind == "brute" ? 0.7 : 1) * speedScale()
    var z = Zombie(id: zSeq, dir: ((zAim + rel) % 8 + 8) % 8, dist: 9 + Math.random() * 2, speed: speed, hp: kind == "brute" ? 2 : 1, kind: kind, nextSound: 0)
    zSound(&z)
    zZombies.append(z)
    zToSpawn -= 1
}

/// One tenth of a second of the fight.
func zTick(_ dt: Double) {
    if zTrain < 0 && zToSpawn > 0 && zZombies.count < maxAtOnce() {
        zSpawnIn -= dt
        if zSpawnIn <= 0 {
            spawnZombie()
            zSpawnIn = Swift.max(3.5 - Double(zWave) * 0.25, 1.5) + Math.random()
        }
    }
    // your own footsteps, under you
    if zTrain < 0 {
        zStepIn -= dt
        if zStepIn <= 0 {
            zStepN += 1
            play("z_step" + str(Int(Math.random() * 6)), [.x(zStepN % 2 == 0 ? -0.15 : 0.15), .y(-1.4), .z(0), .gain(0.55), .rate(0.95 + Math.random() * 0.1)])
            zStepIn = 0.62
        }
    }
    for i in zZombies.indices {
        // walking toward one brings it closer faster; walking away buys time
        let walk = zTrain < 0 ? WALK * cos(Double(zRel(zZombies[i])) * Double.pi / 4) : 0
        zZombies[i].dist -= (zZombies[i].speed + walk) * dt
        zZombies[i].nextSound -= dt
        if zZombies[i].nextSound <= 0 { zSound(&zZombies[i]) }
    }
    if let i = zZombies.firstIndex(where: { $0.dist <= 0.9 }) { zBitten(i) }
}

private func zBitten(_ i: Int) {
    let z = zZombies[i]
    play("z_bite", place(zRel(z), 0.6) + [.gain(1.6)])
    audio.haptic("boom")
    view?.flash()
    zHealth -= 1
    // you shove it away; it comes back
    zZombies[i].dist = 4
    zZombies[i].nextSound = 1.5
    if zHealth <= 0 { zDie(); return }
    say(zHealth == 1 ? "Bitten. One hit left." : "Bitten. " + str(zHealth) + " hits left.")
    zStatusText()
}

func zGesture(_ g: ZGesture) {
    guard zRunning, !paused else { return }
    switch g {
    case .turnLeft, .turnRight:
        zAim = (zAim + (g == .turnRight ? 1 : 7)) % 8
        tone([.type("triangle"), .f(g == .turnRight ? 520 : 440), .dur(0.05), .gain(0.12), .z(-0.5)])
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
            play("z_die" + str(Int(Math.random() * 2)), place(0, z.dist) + [.delay(0.12), .gain(1.4), .rate(z.kind == "brute" ? 0.85 : 1)])
            zAfterKill()
        } else {
            zZombies[i] = z
            zZombies[i].dist += 1.2   // it staggers back
            play("z_groan" + str(Int(Math.random() * Double(Z_GROANS))), place(0, z.dist + 1.2) + [.delay(0.15), .rate(0.75), .gain(1.6)])
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
    if full, let z = zZombies.min(by: { $0.dist < $1.dist }) {
        s += " Nearest: " + zDirName(zRel(z)) + ", " + zDistName(z.dist) + "."
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

private let HOWTO = "You keep walking on your own, toward wherever you face. Swipe left or right to turn. Tap to shoot when the groaning is in the middle of your head. Swipe down to reload. Swipe up to hear your bullets, health and what's left. Two fingers double-tap to pause."

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
    arena("Wave " + str(zWave), "Wave " + str(zWave) + ". " + str(waveSize()) + " of them. " + (zWave == 1 ? "They're coming from in front of you and the sides." : zWave == 3 ? "From now on, they can come from behind you too." : "Listen."))
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
    let healed = zHealth < 3
    zHealth = Swift.min(zHealth + 1, 3)
    chime()
    show("Wave " + str(zWave) + " cleared", "Silence. For now." + (healed ? " You catch your breath: " + str(zHealth) + " hits left." : "") + "\n\nWave " + str(zWave + 1) + " brings " + str(4 + (zWave + 1) * 2) + " of them, and they're faster.", [
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
    zWave = 0; zKills = 0; zHealth = 3; zShots = 0; zHits = 0; zAim = 0; zTrain = -1
    zStartWave()
}

/* ---------- training ---------- */

private let TRAIN: [String] = [
    "Training. A zombie is straight ahead, chained to a post. It can't reach you. Tap to shoot it.",
    "Got it. Your gun holds eight bullets. Swipe down to reload. Try it now.",
    "Good. The next one is on your right. Swipe right to turn toward it. When the groaning is in the middle of your head, tap.",
    "Now one behind you on the left. Swipe left until it's in front of you. Listen for the soft tick: it means one is right ahead. Then tap.",
    "Last thing. Swipe up any time to hear your bullets, your health, and where the nearest one is. Try it.",
]

private func zTrainSpawn(_ rel: Int) {
    zSeq += 1
    var z = Zombie(id: zSeq, dir: ((zAim + rel) % 8 + 8) % 8, dist: 5, speed: 0, hp: 1, kind: "walker", nextSound: 0)
    zSound(&z)
    zZombies = [z]
}

private func zTrainShow() {
    let step = zTrain
    arena("Training", TRAIN[step])
    if step == 0 { zTrainSpawn(0) }
    if step == 2 { zTrainSpawn(2) }
    if step == 3 { zTrainSpawn(-3) }
}

private func zTrainNext() {
    zTrain += 1
    if zTrain >= TRAIN.count {
        zRunning = false
        zTrain = -1
        zTrained = true
        clearScene()
        chime()
        show("Training done", "That's everything. In a real fight they keep coming, more at once each wave, and if one reaches you it bites. Three bites and it's over.\n\nTwo fingers double-tap pauses the fight at any time.", [
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
            Choice("Turn the phone sideways for the fight: " + (zSideways ? "on" : "off")) { zSideways.toggle(); go("x_start") },
            Choice("Back", to("title")),
        ]
        show("Last Stand", "You, a pistol, and the dark. They come in waves, from every side. You'll only hear them.\n\n" + HOWTO + (zTrained ? "" : "\n\nNew here? Start with the training.") + (bestWave > 0 ? "\n\nYour best: " + str(bestWave) + (bestWave == 1 ? " wave." : " waves.") : ""), choices)
    }
    scene("x_train") {
        zWave = 0; zHealth = 3; zAmmo = CLIP; zAim = 0; zReloading = false; zZombies = []
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
