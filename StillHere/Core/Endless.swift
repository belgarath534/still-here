import Foundation

// Endless Night: a survival mode. Each night is a run of random encounters taken from the story,
// a little faster and longer than the one before. One mistake ends the run.

var night = 0.0, encounterN = 0.0, encountersTonight = 0.0
var bestNight: Double {
    get { UserDefaults.standard.double(forKey: "stillhere-bestnight") }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-bestnight") }
}
var lastEncounter = ""
/// what the current encounter is doing (the play-test bot reads these too)
var eSide = 0.0, eLive = false, eReal = false, eMoves = 0.0

/// Reaction time for timed moments: shrinks every night, but never below a fair minimum.
func endlessLimit() -> Double {
    if opts.extraTime { return 16000 }
    return Swift.max(hardOr(4000, 3000), hardOr(9500, 6500) - night * 600)
}

/// The run is over: shows how far you got.
func endlessDie(_ text: String) {
    clearScene()
    silenceAll()
    show("", "", [])
    play("found", [.x(0.35), .z(0.2), .gain(1.6)])
    after(1700) { scream() }
    after(4300) {
        let survived = night - 1
        let record = survived > bestNight
        if record { bestNight = survived }
        show("The night is over", text + "\n\nYou survived " + (survived == 1 ? "1 night" : str(survived) + " nights") + "." + (record && survived > 0 ? " That's your best yet." : bestNight > 0 ? " Your best is " + str(bestNight) + "." : ""), [
            Choice("Try again", to("e_start")),
            Choice("Main menu", to("title")),
        ])
    }
}

/// Picks the next encounter, never the same kind twice in a row.
func endlessNext() {
    clearScene()
    if encounterN >= encountersTonight { go("e_dawn"); return }
    encounterN += 1
    var kinds = ["dodge", "window", "door", "hold", "vents", "breath"]
    if night < 2 { kinds.removeAll { $0 == "breath" } }
    kinds.removeAll { $0 == lastEncounter }
    lastEncounter = pick(kinds)
    heartbeat(100 + Swift.min(night * 5, 40))
    after(1500 + Math.random() * 2500) {
        switch lastEncounter {
        case "dodge": eDodge()
        case "window": eWindow()
        case "door": eDoor()
        case "hold": eHold()
        case "vents": eVents()
        default: eBreath()
        }
    }
    listening()
}

private func header() -> String { "Night " + str(night) + ", " + str(encounterN) + " of " + str(encountersTonight) }
private func survived(_ text: String) {
    heartbeat(90)
    show(header(), text, [Choice("Keep listening", { endlessNext() })])
    after(3500) { endlessNext() }
}

/* ---------- encounters ---------- */

/// Something rushes at you from one side. Dodge the other way.
func eDodge() {
    eSide = pick([-1.0, 1]); eLive = false
    let side = eSide
    show(header(), "Something is coming. Fast. Dodge away from the side it comes from.", [
        Choice("Dodge left") { if !eLive { say("Wait for it."); return }; if side < 0 { endlessDie("You dodged straight into it.") } else { clearScene(); whoosh(side * 1.2); survived("It rushes past you. So close you feel the air move.") } },
        Choice("Dodge right") { if !eLive { say("Wait for it."); return }; if side > 0 { endlessDie("You dodged straight into it.") } else { clearScene(); whoosh(side * 1.2); survived("It rushes past you. So close you feel the air move.") } },
    ])
    let cue = 1500 + Math.random() * 1500
    after(cue) {
        eLive = true
        let x = side * 3.5
        steps(5, [.from(x, 0, -7), .to(x * 0.6, 0, -1.5), .gap(0.32), .rate(1.3)])
        play("breath", [.x(x * 0.7), .z(-3), .delay(0.6), .gain(1.3), .rate(0.85), .to(x * 0.5, 0, -1), .toSec(1.5)])
    }
    after(cue + endlessLimit()) { endlessDie("You froze. It didn't.") }
}

/// It taps on a window. Lock that side, fast.
func eWindow() {
    eSide = pick([-1.0, 1]); eLive = false
    let side = eSide
    let lock = { (s: Double) in
        if !eLive { say("Wait for the tap."); return }
        if s != side { endlessDie("You locked the wrong side. The tapping was on the " + (side < 0 ? "left" : "right") + "."); return }
        clearScene()
        play("lock", [.x(side), .z(-0.3), .gain(1.6)])
        survived("Clunk. The handle rattles. Holds.")
    }
    show(header(), "Footsteps on gravel, circling you. When it taps on a window, lock that side.", [
        Choice("Lock the left side") { lock(-1) },
        Choice("Lock the right side") { lock(1) },
    ])
    let a0 = Math.random() * Math.PI * 2
    for i in upTo(5) {
        let a = a0 + i * 0.6
        after(i * 600) { play("gravel" + str(i % 3), [.x(Math.cos(a) * 2.5), .z(Math.sin(a) * 2.5), .gain(0.9)]) }
    }
    let cue = 3600 + Math.random() * 1500
    after(cue) {
        eLive = true
        play("tap0", [.x(side * 1.1), .z(-0.2), .gain(1.6)])
        play("tap1", [.x(side * 1.1), .z(-0.2), .gain(1.6), .delay(0.35)])
        play("tap0", [.x(side * 1.1), .z(-0.2), .gain(1.6), .delay(0.7)])
    }
    after(cue + endlessLimit()) { play("glassbang", [.x(side), .z(-0.2), .gain(2)]); endlessDie("You froze. The window gave.") }
}

/// Someone knocks. A real person comes with footsteps, keys and an engine running. A copy is just suddenly there.
@MainActor func eDoorVisit() async throws {
    eReal = Math.random() < 0.35
    let real = eReal
    listening()
    if real {
        engine(0.2)
        gravel(6, [.from(4, 0, -6), .to(0.5, 0, -2), .gap(0.35), .gain(1)])
        play("keys", [.x(1.5), .z(-3), .delay(1.2)])
        try await wait(2600)
        play("knock", [.z(-2.2), .gain(1.6), .rate(1.2)]); play("knock", [.z(-2.2), .gain(1.6), .rate(1.2), .delay(0.5)])
        try await wait(1200)
        play("jess_real", [.z(-2.2), .lowpass(5000), .gain(1.2)])
        try await wait(len("jess_real") + 600)
    } else {
        play("knock", [.z(-2.2), .gain(1.2)])
        try await wait(2200)
        let fake = pick(["jess_code", "neighbor", "me", "i_r9", "c5_fake"])
        play(fake, [.z(-2.2), .phone(fake == "jess_code"), .lowpass(4000), .gain(1.4)])
        try await wait(len(fake) + 800)
    }
    show(header(), "Someone is at the door. Real people make noise getting there. Copies are just suddenly there.", [
        Choice("Open the door") {
            if real { engine(0); survived("Jess falls through the door, soaked, and you lock it behind her. “Don't open it again. Not for anyone.”") }
            else { endlessDie("You opened the door. Nobody walked up to it. Nobody had to.") }
        },
        Choice("Stay quiet") {
            if real { engine(0); endlessDie("You stayed quiet. Outside, the engine stops. Then the screaming does.") }
            else {
                clearScene(); listening()
                play("scratch", [.z(-2), .gain(1.2), .rate(0.8)]); play("scratch", [.z(-2), .gain(1.2), .rate(0.7), .delay(1.2)])
                after(4500) { survived("It scratches at the door for a while. Then it gives up.") }
            }
        },
    ])
}
func eDoor() { spawn { try await eDoorVisit() } }

/// It's in the room. Don't touch anything until it leaves.
func eHold() {
    let dir = pick([-1.0, 1])
    let dur = 14000 + Swift.min(night, 6) * 2000
    show(header(), "It's in the room with you. Don't press anything. Wait until it leaves.", [
        Choice("Run") { endlessDie("You ran. It was faster.") },
        Choice("Hide") { endlessDie("You moved. It heard.") },
    ])
    play("creak", [.z(-3.5), .gain(1.4)])
    let n = 12.0
    for i in upTo(n) {
        let a = Math.PI * 1.5 + dir * (i / n) * Math.PI * 2, r = 2.2 - i * 0.08
        after(2000 + i * 900) { play("steps", [.x(Math.cos(a) * r), .z(Math.sin(a) * r), .rate(0.9 + Math.random() * 0.1), .gain(0.9)]) }
    }
    after(6000) { for i in upTo(3) { play("breath", [.x(-dir * 0.8), .z(-0.3), .delay(i * 1.3), .gain(1), .to(dir * 0.8, 0, -0.3), .toSec(4)]) } }
    after(dur - 4000) { steps(5, [.from(1, 0, 1.5), .to(4, 0, 6), .gap(0.8)]) }
    after(dur) { survived("The footsteps fade. It's gone. For now.") }
}

/// Something crawls through the ceiling. Go the other way.
func eVents() {
    eSide = pick([-1.0, 1]); eLive = false
    let side = eSide
    let goSide = { (s: Double) in
        if !eLive { say("Listen for the vents first."); return }
        if s == side { endlessDie("You went toward the sound. The ceiling tile above you lifts."); return }
        clearScene()
        conc(6, [.from(0, 0, 0), .to(s * 3, 0, -3), .gap(0.3), .gain(0.8)])
        survived("You slip past. Above you, the crawling goes the other way.")
    }
    show(header(), "A corner. Something heavy is moving in the ceiling vents. Go the other way.", [
        Choice("Go left") { goSide(-1) },
        Choice("Go right") { goSide(1) },
    ])
    after(1800) { eLive = true; crawl(side * 2, 3500) }
    after(1800 + endlessLimit() + 2000) { endlessDie("You waited too long. It came down.") }
}

/// Move only while it breathes. Three moves.
func eBreath() {
    eLive = false; eMoves = 0
    let labels = ["Take a step", "Another step", "Last step"]
    func breathe(_ first: Double? = nil) {
        after(first ?? 2500 + Math.random() * 3500) {
            eLive = true
            for i in upTo(2) { play("breath", [.x(0.1), .z(0.6), .delay(i * 1.25), .gain(1.4), .rate(0.9 + Math.random() * 0.1)]) }
            after(opts.extraTime ? 4500 : 2900) { eLive = false; breathe() }
        }
    }
    func present() {
        show(header(), eMoves == 0 ? "It's right behind you. Only move while it breathes. The sound covers you." : "It didn't hear. Wait for the next breath.", [
            Choice(labels[Int(eMoves)]) {
                if !eLive { endlessDie("You moved in the silence. Something leans forward until its breath is on your neck."); return }
                gravel(1, [.from(0, 0, -0.3), .to(0, 0, -0.3), .gain(0.4)])
                eMoves += 1
                if eMoves >= 3 { clearScene(); survived("You're out of its reach.") } else { present() }
            },
        ])
    }
    present()
    breathe(3000)
}

/* ---------- scenes ---------- */

func registerEndless() {
    scene("e_start") {
        silenceAll()
        night = 0
        show("Endless Night", "No story. No checkpoints. Just the dark, and things that want in.\n\nEvery night brings a handful of encounters from the whole game: something rushing at you, tapping at the windows, knocking at the door, circling you, crawling in the vents. Each night is a little faster and a little longer.\n\nOne mistake and it's over. " + (bestNight > 0 ? "Your best: " + str(bestNight) + (bestNight == 1 ? " night." : " nights.") : "How many nights can you last?"), [
            Choice("Begin", to("e_night")),
            Choice("Back", to("title")),
        ])
    }
    scene("e_night") {
        night += 1
        encounterN = 0
        encountersTonight = Swift.min(3 + Math.floor(night / 2), 7)
        lastEncounter = ""
        music("m_drone", 0.13, 4)
        rain(0.06 + Swift.min(night, 6) * 0.02)
        show("Night " + str(night), night == 1 ? "The power goes out. Somewhere in the house, something starts to move." : "The sun goes down again. It's back. It's learned a little more about you.", [
            Choice("Listen") { endlessNext() },
        ])
    }
    scene("e_dawn") {
        heartStop(); rain(0)
        music("m_rest", 0.2, 4)
        birds(true)
        if night > bestNight { bestNight = night }
        show("Dawn", "Grey light. Birds. You made it through night " + str(night) + ".\n\nYou don't sleep. You know it's coming back.", [
            Choice("Next night", to("e_night")),
            Choice("Main menu", to("title")),
        ])
    }
}
