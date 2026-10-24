// Plays the whole game automatically, much faster than real time, with a silent stand-in
// for the sound system that knows how long every real sound file is.
// Run: swift run StillHereSim [chapter names...]
@testable import StillHereCore
import Foundation

final class MockAudio: AudioBackend {
    var durations: [String: Double] = [:]
    var loaded: [String: Double] = [:]
    var stored: [String: PCM] = [:]
    var played: [String] = []
    init() {
        let url = Bundle.module.url(forResource: "durations", withExtension: "json")!
        durations = try! JSONDecoder().decode([String: Double].self, from: Data(contentsOf: url))
    }
    func load(_ names: [String]) async -> Bool {
        for n in names {
            guard let d = durations[n] else { print("  !! no sound file for \(n)"); return false }
            loaded[n] = d
        }
        return true
    }
    func unload(_ names: [String]) { for n in names { loaded[n] = nil } }
    func duration(_ name: String) -> Double? { loaded[name] }
    func pcm(_ name: String) -> PCM? {
        if let p = stored[name] { return p }
        guard let d = loaded[name] else { return nil }
        return PCM([Float](repeating: 0, count: Int(d * 1000)), rate: 1000)
    }
    func store(_ name: String, _ pcm: PCM?) { stored[name] = pcm; loaded[name] = pcm?.duration }
    func play(_ src: Source, _ p: PlayParams) -> Int {
        if case .named(let n) = src { played.append(n) }
        return 0
    }
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
    func record(seconds: Double) async throws -> PCM { PCM([Float](repeating: 0, count: Int(seconds * 1000)), rate: 1000) }
}

final class MockView: GameView {
    var log: [String] = []
    var notes = 0
    func render(_ s: Screen) {}
    func announce(_ msg: String) {}
    func flash() {}
    func contentNote(_ msg: String, then: @escaping () -> Void) { notes += 1; then() }
    func pauseChanged(_ paused: Bool) {}
}

struct Failure: Error { let msg: String }

let SPEED = 40.0
let mockAudio = MockAudio()
let mockView = MockView()
var missing: [String: Set<String>] = [:]
var currentRun = ""

/// Waits (in game time) until `cond` is true.
@MainActor func waitFor(_ what: String, _ timeoutMs: Double = 400_000, _ cond: () -> Bool) async throws {
    let deadline = nowMs() + timeoutMs / SPEED
    while !cond() {
        if nowMs() > deadline { throw Failure(msg: "timed out waiting for \(what); screen is “\(screen.title)”: \(screen.text.prefix(60))") }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
}
@MainActor func waitTitle(_ p: String) async throws { try await waitFor("title “\(p)”") { screen.title.hasPrefix(p) } }
@MainActor func waitChoice(_ p: String) async throws { try await waitFor("choice “\(p)”") { screen.choices.contains { $0.label.hasPrefix(p) } } }
@MainActor func click(_ p: String) async throws {
    try await waitChoice(p)
    let i = screen.choices.firstIndex { $0.label.hasPrefix(p) }!
    choose(i, screenID: screen.id)
    try await Task.sleep(nanoseconds: 3_000_000)
}
@MainActor func note() -> String { "\(screen.title) | " + screen.text.prefix(50).replacingOccurrences(of: "\n", with: " ") }

/* ---------- chapter scripts ---------- */

@MainActor func ch1() async throws {
    try await waitTitle("3:12"); try await click("Listen")
    try await waitTitle("Knocking"); try await click("Stay silent")
    try await waitTitle("The closet"); try await click("Continue")
    try await waitTitle("Unknown caller"); try await click("Answer")
    try await waitTitle("The call"); try await click("Continue")
    try await waitTitle("Don't move")
    try await waitTitle("It left"); try await click("Step into")
    try await waitTitle("The hallway"); try await click("I'm ready")
    for r in 1...3 {
        try await waitFor("round \(r)") { roundLive && chaseRoundN == Double(r) }
        try await click(roundSide > 0 ? "Dodge left" : "Dodge right")
        if r < 3 { try await waitFor("round \(r + 1) starts") { chaseRoundN == Double(r + 1) } }
    }
    try await click("Keep going")
    try await waitTitle("The front door"); try await click("Keep going to the bathroom")
    try await waitTitle("The bathroom"); try await click("Wait")
    try await waitTitle("Wait for the sun")
    try await waitTitle("Dawn"); try await click("Open the bathroom")
    try await waitTitle("You survived"); try await click("Main menu")
    try await waitTitle("Still here")
}

@MainActor func ch2() async throws {
    try await waitTitle("Chapter Two"); try await click("Lie down")
    try await waitTitle("Unknown caller"); try await click("Decline")
    try await waitTitle("The call"); try await click("Continue")
    try await waitTitle("Waiting"); try await click("Wait")
    while true {
        try await waitFor("door or car") { screen.title == "Someone's at the door" || screen.title.hasPrefix("The car") || screen.title == "Silence" }
        if screen.title.hasPrefix("The car") { break }
        if screen.title == "Silence" { try await click("Keep waiting"); try await waitFor("next knock") { screen.title != "Silence" }; continue }
        let v = visits[visitN]
        try await click(v == "real" ? "Open the door" : "Stay quiet")
        try await waitFor("door answered") { screen.title != "Someone's at the door" }
    }
    try await click("Close your eyes")
    try await waitTitle("End of Chapter Two")
}

@MainActor func ch3() async throws {
    try await waitTitle("Chapter Three"); try await click("Listen")
    try await waitTitle("The radio"); try await click("Turn the radio off")
    try await waitTitle("The back seat"); try await click("Continue")
    try await waitTitle("The trunk"); try await click("Agree")
    try await waitTitle("Gas-N-Go"); try await click("Lock the doors")
    for r in 1...4 {
        try await waitFor("tap \(r)") { lockLive && lockRound == Double(r) }
        try await click(lockSide < 0 ? "Lock the left" : "Lock the right")
        if r < 4 { try await waitFor("round \(r + 1)") { lockRound == Double(r + 1) } }
    }
    try await click("Keep waiting")
    try await waitTitle("Two voices"); try await click(realSide < 0 ? "Unlock the left" : "Unlock the right")
    try await waitTitle("Go"); try await click("Keep driving")
    try await waitTitle("Sunrise"); try await click("Rest your head")
    try await waitTitle("End of Chapter Three")
}

@MainActor func ch4() async throws {
    try await waitTitle("Chapter Four"); try await click("Listen")
    try await waitTitle("The plan"); try await click("I'm ready")
    while currentScene == "c4sneak" {
        try await waitFor("breath") { breathLive || currentScene != "c4sneak" }
        if currentScene != "c4sneak" { break }
        try await click(SNEAK[sneakStep])
        try await waitFor("breath ends") { !breathLive || currentScene != "c4sneak" }
    }
    try await waitTitle("Locked in"); try await click("Walk away")
    for _ in 0..<3 { try await waitTitle("Don't stop"); try await click("Keep walking") }
    try await waitTitle("Hold on")
    try await waitTitle("Ending: Escape"); try await click("Listen to the morning news")
    try await waitTitle("Morning news")
}

@MainActor func interlude() async throws {
    try await waitTitle("Interlude: The Station"); try await click("Tell the truth")
    try await waitTitle("The cruiser"); try await click("Continue")
    for t in ["Interview Room B", "Mrs. Alvarez", "The doors"] { try await waitTitle(t); try await click("“") }
    try await waitTitle("The tape"); try await click("Wait")
    try await waitTitle("Blackout"); try await click("Wait for him")
    while true {
        try await waitFor("door or hallway") { screen.title == "Someone at the door" || screen.title == "The hallway" }
        if screen.title == "The hallway" { break }
        try await click(doorSeq[doorIdx] == "real" ? "Open the door" : "Stay in your seat")
        try await waitFor("door handled") { screen.title != "Someone at the door" }
    }
    try await click("Follow Ruiz")
    for c in 1...3 {
        try await waitFor("corner \(c)") { ventLive && junction == Double(c) }
        try await click(ventSide > 0 ? "Go left" : "Go right")
        if c == 1 { try await waitTitle("The cells"); try await click("Keep moving") }
        if c == 2 { try await waitTitle("A voice in the dark"); try await click("Keep following") }
    }
    try await waitTitle("The radio"); try await click("Run")
    try await waitTitle("The lobby"); try await click("Hold her")
    try await waitTitle("Elk Ridge"); try await click("Go")
    try await waitTitle("End of the Interlude")
}

@MainActor func ch5() async throws {
    try await waitTitle("Chapter Five"); try await click("Light the fire")
    try await waitTitle("The fire"); try await click("Take her hand")
    try await waitChoice("“I'm glad"); try await click("“I'm glad")
    try await waitTitle("Her hand"); try await click("Remember")
    try await waitTitle("The first night")
    try await waitTitle("Three weeks"); try await click("Say it back")
    try await waitChoice("Continue"); try await click("Continue")
    try await waitTitle("The storm"); try await click("Lock the door")
    var asked = false
    while true {
        try await waitFor("door or inside") { screen.title == "Someone at the door" || screen.title == "Inside" }
        if screen.title == "Inside" { break }
        let v = c5visits[c5idx]
        if !asked && screen.choices.contains(where: { $0.label.hasPrefix("Ask") }) {
            asked = true
            let id = screen.id
            try await click("Ask")
            try await waitFor("answer") { screen.id != id && screen.title == "Someone at the door" }
        }
        try await click(v == "real" ? "Open the door" : "Stay quiet")
        try await waitFor("door handled") { screen.title != "Someone at the door" }
        asked = false
    }
    try await click("Hold her")
    try await waitTitle("Morning"); try await click("Let it ring")
    try await waitTitle("End of Chapter Five")
}

@MainActor func ch6() async throws {
    try await waitTitle("Chapter Six"); try await click("Open the door")
    try await waitTitle("The tapes")
    for t in ["Tape one", "Tape two", "Tape three"] {
        try await waitChoice(t); try await click(t)
        try await waitTitle("The tapes")
    }
    try await click("Look at the bottom")
    try await waitChoice("Turn off"); try await click("Turn off")
    try await waitTitle("Forty years"); try await click("Try to sleep")
    try await waitTitle("The tape player"); try await click("Cover Ruiz")
    try await waitTitle("End of Chapter Six")
}

@MainActor func ch7() async throws {
    try await waitTitle("Chapter Seven"); try await click("Go inside")
    try await waitTitle("The radio")
    while foundStations.length < 3 && currentScene == "c7tune" {
        try await waitFor("dial buttons") { screen.choices.count == 3 || currentScene != "c7tune" }
        if currentScene != "c7tune" { break }
        let remain = targets.enumerated().filter { !foundStations.includes(Double($0.offset)) }.map { $0.element }
        guard let tgt = remain.min(by: { abs($0 - dial) < abs($1 - dial) }) else { break }
        try await click(tgt < dial ? "Turn the dial down" : "Turn the dial up")
    }
    try await waitTitle("The stairs")
    for l in CLIMB {
        try await waitFor("gust") { gustLive }
        try await click(l)
        try await waitFor("gust over") { !gustLive || currentScene != "c7stairs" }
    }
    try await waitTitle("The booth"); try await click("Search the DJ")
    try await waitChoice("Pull the breaker"); try await click("Pull the breaker")
    try await waitTitle("End of Chapter Seven")
}

@MainActor func ch8() async throws {
    try await waitTitle("Chapter Eight"); try await click("Go to room 312")
    try await waitTitle("Room 312"); try await click("Look through")
    try await waitChoice("Let Jess ask"); try await click("Let Jess ask")
    try await waitTitle("It's a trap"); try await click("Get her")
    try await waitTitle("The stairwell"); try await click("Start down")
    for l in 1...3 {
        try await waitFor("landing \(l)") { stairLive && landing == Double(l) }
        try await click(stairSide > 0 ? "Keep going down" : "Go through the door")
        if l == 2 { try await waitTitle("A voice in the vents"); try await click("Keep going") }
    }
    try await waitTitle("End of Chapter Eight")
}

@MainActor func chZ() async throws {
    try await waitTitle("Interlude Two"); try await click("Answer it")
    try await waitTitle("Danny"); try await click("Ask him")
    try await waitTitle("The file room")
    try await waitTitle("End of Interlude Two")
}

@MainActor func ch9() async throws {
    try await waitTitle("Chapter Nine"); try await click("Run")
    try await waitTitle("Separated"); try await click("Get up and listen")
    var wrongDone = false
    for w in 1...4 {
        try await waitFor("woods \(w)") { woodsLive && woodsStep == Double(w) }
        if !wrongDone {
            // one wrong turn is allowed on normal difficulty
            wrongDone = true
            let wrong = [-1.0, 0, 1].first { $0 != woodsDir }!
            try await click(wrong < 0 ? "Go left" : wrong == 0 ? "Go ahead" : "Go right")
            try await waitTitle("Wrong way"); try await click("Listen again")
            try await waitFor("woods \(w) again") { woodsLive && woodsStep == Double(w) }
        }
        try await click(woodsDir < 0 ? "Go left" : woodsDir == 0 ? "Go ahead" : "Go right")
    }
    try await waitTitle("Ruiz"); try await click("“We're not leaving")
    try await waitTitle("End of Chapter Nine")
}

@MainActor func ch10() async throws {
    try await waitTitle("Chapter Ten"); try await click("Go in")
    try await waitTitle("The shaft"); try await click("Lower yourselves")
    try await waitTitle("The flooded tunnel"); try await click("Wade")
    try await waitTitle("The radios"); try await click("Pick up the cassette")
    try await waitTitle("The radios"); try await click("Squeeze")
    try await waitTitle("The voices"); try await click("Just listen")
    try await waitTitle("End of Chapter Ten")
}

@MainActor func ch11() async throws {
    try await waitTitle("Chapter Eleven"); try await click("Record my voice")
    try await waitTitle("Which one is you"); try await click("Crawl to her")
    try await waitTitle("End of Chapter Eleven")
}

@MainActor func ch12(_ ending: String) async throws {
    try await waitTitle("Chapter Twelve"); try await click("Hold her hand")
    try await waitTitle("Starve it"); try await click("Squeeze her hand")
    try await waitTitle("The end of it")
    switch ending {
    case "silence": try await click("Don't blow anything up"); try await waitTitle("Ending: Silence")
    case "promise": try await click("Light it, and stay behind"); try await waitTitle("Ending: The Promise")
    default: try await click("Light the detonator and run"); try await waitTitle("Ending: Together")
    }
}

@MainActor func ch13() async throws {
    try await waitTitle("Chapter Thirteen"); try await click("Set up the smart")
    try await waitTitle("Turn on the lights"); try await click("Make dinner")
    try await waitTitle("Ruiz"); try await click("Hug him")
    try await waitTitle("Date night"); try await click("Walk by the river")
    try await waitChoice("Continue"); try await click("Continue")
    try await waitTitle("The news"); try await click("Go to bed")
    try await waitTitle("Pocket dial"); try await click("Check your phone")
    try await waitTitle("End of Chapter Thirteen")
}

@MainActor func ch14() async throws {
    try await waitTitle("Chapter Fourteen"); try await click("Go to bed")
    try await waitTitle("Emergency alert"); try await click("Find them")
    let names = ["Kitchen", "Bedroom", "Living room", "Hallway"]
    for k in 1...4 {
        try await waitFor("speaker \(k)") { huntLive && hunt == Double(k) }
        if k == 1 { try await click(names[(Int(huntRoom) + 1) % 4]) }
        try await click(names[Int(huntRoom)])
    }
    try await waitTitle("The front door"); try await click("Run and throw")
    try await waitTitle("End of Chapter Fourteen")
}

@MainActor func ch15(_ keep: Bool) async throws {
    try await waitTitle("Chapter Fifteen"); try await click("Drive to")
    try await waitTitle("The barrel"); try await click("Throw the first")
    for _ in 0..<3 { try await waitChoice("Throw in the next"); try await click("Throw in the next") }
    try await waitTitle("The last tape"); try await click(keep ? "Tell him" : "Let Jess")
    try await waitTitle("End of Chapter Fifteen")
}

@MainActor func ch16(_ delete: Bool) async throws {
    try await waitTitle("Chapter Sixteen"); try await click("Start deleting")
    for _ in 0..<4 {
        try await waitChoice("Delete:"); try await click("Delete:")
        try await waitChoice("Keep going"); try await click("Keep going")
    }
    try await waitTitle("The last recording")
    if delete {
        try await click("Delete my voice"); try await waitTitle("Silence")
        guard !has("myvoice") else { throw Failure(msg: "recording was not deleted") }
        try await click("Say something"); try await waitTitle("Ending: Unrecorded")
    } else {
        try await click("Keep it"); try await waitTitle("Ending: Echo")
    }
}

/// Dies on purpose, then retries from the checkpoint.
@MainActor func deathAndRetry() async throws {
    try await waitTitle("3:12"); try await click("Listen")
    try await waitTitle("Knocking"); try await click("Call out")
    try await waitTitle("Your voice"); try await click("Continue")
    try await waitTitle("Unknown caller"); try await click("Decline")
    try await waitTitle("Voicemail"); try await click("Continue")
    try await waitTitle("Don't move"); try await click("Run for the door")
    try await waitTitle("It found you"); try await click("Try again")
    try await waitTitle("Don't move")
    // pause for a while in the middle of the hold-still: nothing may move on while paused
    openPause()
    let before = screen.id
    try await Task.sleep(nanoseconds: UInt64(60_000 / SPEED * 1_000_000))
    guard screen.id == before else { throw Failure(msg: "the game moved on while paused") }
    closePause()
    try await waitTitle("It left")
}

/* ---------- runner ---------- */

let RUNS: [(String, String, @MainActor () async throws -> Void)] = [
    ("ch1", "s1", ch1), ("death", "s1", deathAndRetry), ("ch2", "c2", ch2), ("ch3", "c3", ch3), ("ch4", "c4", ch4),
    ("interlude", "i1", interlude), ("ch5", "c5", ch5), ("ch6", "c6", ch6), ("ch7", "c7", ch7), ("ch8", "c8", ch8),
    ("z", "z1", chZ), ("ch9", "c9", ch9), ("ch10", "c10", ch10), ("ch11", "c11", ch11),
    ("ch12-together", "c12", { closeness = 3; toldTruth = 0; try await ch12("together") }),
    ("ch12-promise", "c12", { closeness = 0; toldTruth = 0; try await ch12("promise") }),
    ("ch12-silence", "c12", { closeness = 5; toldTruth = 3; try await ch12("silence") }),
    ("ch13", "c13", ch13), ("ch14", "c14", ch14), ("ch15-keep", "c15", { try await ch15(true) }), ("ch15-burn", "c15", { try await ch15(false) }),
    ("ch16-delete", "c16", { try await ch16(true) }), ("ch16-echo", "c16", { try await ch16(false) }),
]

@MainActor func runAll() async {
    let only = Set(CommandLine.arguments.dropFirst())
    audio = mockAudio
    view = mockView
    timeScale = SPEED
    onMissingSound = { name in missing[currentRun, default: []].insert(name) }
    UserDefaults.standard.removeObject(forKey: "stillhere-opts")
    startGame()
    _ = await loadSounds()
    checked = true
    var failed = 0
    for (name, id, script) in RUNS where only.isEmpty || only.contains(name) {
        currentRun = name
        resetProgress()
        let t0 = nowMs()
        go("title")
        do {
            try await start(id)
            try await script()
            print("PASS \(name) (\(Int((nowMs() - t0) * SPEED / 1000)) game seconds) — \(note())")
        } catch {
            failed += 1
            print("FAIL \(name): \((error as? Failure)?.msg ?? "\(error)")")
        }
        if let m = missing[name], !m.isEmpty { print("  missing sounds in \(name): \(m.sorted().joined(separator: ", "))") }
    }
    print(failed == 0 ? "ALL PASSED" : "\(failed) FAILED")
    exit(failed == 0 ? 0 : 1)
}

Task { @MainActor in await runAll() }
dispatchMain()
