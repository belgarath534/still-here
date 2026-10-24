import Foundation

// Splash, main menu, settings and the other menu screens.

var dannyKept = false
var checked = false, checkNext = "s1", checkSide = 0.0
var twistDone = false

func act4Open() -> Bool { done.contains { $0 >= 14 } }
func chapterOf(_ id: String) -> ChapterInfo {
    if id.hasPrefix("c"), let n = Int(id.dropFirst().prefix(while: { $0.isNumber })) {
        let map = [2: 1, 3: 2, 4: 3, 5: 5, 6: 6, 7: 7, 8: 8, 9: 10, 10: 11, 11: 12, 12: 13, 13: 14, 14: 15, 15: 16, 16: 17]
        return map[n].map { CHAPTERS[$0] } ?? CHAPTERS[0]
    }
    if id.hasPrefix("z") { return CHAPTERS[9] }
    if id.hasPrefix("i") { return CHAPTERS[4] }
    return CHAPTERS[0]
}
func menuMusic() { music("m_air", 0.16, 3); rain(0.03) }

/// Sets everything up. The app calls this once at launch.
func startGame() {
    loadProgress()
    audio.setMaster(opts.master)
    audio.setMusicVolume(opts.musicVol)
    registerMenus()
    registerStory()
    go("splash")
}

@MainActor func boot() async throws {
    if !bootLoaded {
        show("", "Loading sounds…", [])
        if !(await loadSounds()) {
            show("", "Some sounds failed to load.", [Choice("Try again", boot)])
            return
        }
    }
    boom()
    go("title")
}

@MainActor func start(_ target: String) async throws {
    musicCut(); rain(0)
    if !(await loadSounds()) {
        show("", "Some sounds failed to load.", [Choice("Try again") { try await start(target) }])
        return
    }
    checkNext = target
    go(checked ? target : "check")
}

func checkAnswer(_ side: Double) {
    checked = true
    clearScene()
    if side == checkSide {
        show("Headphone check", checkNext == "settings" ? "Correct. Your headphones are working." : "Correct. Your headphones are working.\n\nOne more thing. From now on, nobody can see anything — not you, not it. The power is out. All you have is your ears.\n\nIt can hear you too.", [
            Choice(checkNext == "settings" ? "Back to settings" : "Begin") { go(checkNext) },
        ])
    } else {
        show("Headphone check", "That drip came from your " + (checkSide < 0 ? "left" : "right") + " ear. Your headphones may be on backwards, or you're on speakers. The game is much scarier — and fairer — with headphones on the right way round.", [
            Choice("Test again", to("check")),
            Choice(checkNext == "settings" ? "Back to settings" : "Continue anyway") { go(checkNext) },
        ])
    }
}

/// The last screen of a Chapter Twelve ending.
@MainActor func epilogue(_ id: String, _ title: String, _ text: String, _ lines: [(String, [O], Double)]) async throws {
    for (name, o, extra) in lines { try await say2(name, o, extra) }
    markEnding(id); markDone(14)
    silenceAll(); drips(false)
    let goesOn = id == "together" || id == "silence"
    var choices: [Choice] = []
    if goesOn { choices.append(Choice("Play Act Four: Chapter Thirteen, After", to("c13"))) }
    choices += [
        Choice("Endings found: " + str(endings.length) + " of " + str(ENDINGS.length), to("endings")),
        Choice("Credits", to("credits")),
        Choice("Main menu", to("title")),
    ]
    show(title, text + (goesOn ? "\n\nThe story isn't over. Act Four is now open." : "\n\nThank you for playing Still Here." + (id == "promise" ? " Act Four is now open in Chapters, and picks up after the ending where you both get out." : "")), choices)
}

func registerMenus() {
    scene("splash") {
        silenceAll()
        show("", "Headphones on. Lights off.\n\nWarning: sudden loud sounds and jump scares. No flashing lights.", [
            Choice("Start", boot),
        ])
    }

    scene("title") {
        silenceAll()
        menuMusic()
        var choices: [Choice] = []
        if let cp = checkpoint, SCENES[cp] != nil { choices.append(Choice("Continue: " + chapterOf(cp).name) { try await start(cp) }) }
        choices += [
            Choice("New game") { try await start("s1") },
            Choice("Chapters", to("chapters")),
            Choice("Settings", to("settings")),
            Choice("Endings found: " + str(endings.length) + " of " + str(ENDINGS.length), to("endings")),
            Choice("Hidden tapes: " + str(tapesFound.length) + " of 4", to("tapes")),
            Choice("How to play", to("howto")),
            Choice("Credits", to("credits")),
        ]
        show("Main menu", "Sixteen chapters and two interludes, four or five hours in all. Things change a little every time you play.", choices)
    }

    scene("chapters") {
        menuMusic()
        let total = act4Open() ? CHAPTERS.length : 14
        var choices = CHAPTERS.filter { $0.n < 15 || act4Open() }.map { c in
            Choice(c.name + (done.includes(c.n) ? ", completed" : "")) { try await start(c.id) }
        }
        choices.append(Choice("Back", to("title")))
        show("Chapters", "Pick a chapter. " + (done.length > 0 ? "You've finished " + str(done.length) + " of " + str(total) + "." : "You haven't finished any yet."), choices)
    }

    scene("settings") {
        menuMusic()
        show("Settings", "Changes are saved automatically.", [
            Choice("Test your headphones") { checkNext = "settings"; go("check") },
            Choice("Reset progress", to("reset")),
            Choice("Back", to("title")),
        ], .settings)
    }

    scene("reset") {
        show("Reset progress", "This erases your saved checkpoint, finished chapters, endings and hidden tapes. Your settings stay the same.", [
            Choice("No, keep my progress", to("settings")),
            Choice("Yes, erase my progress") { resetProgress(); say("Progress erased."); go("settings") },
        ])
    }

    scene("howto") {
        menuMusic()
        show("How to play", "Wear headphones. Almost everything in Still Here happens through sound, and sounds come from your left, your right, in front of you, behind you and above you.\n\nEach scene's text is read to you when it appears. Then swipe right to reach the choices, and double-tap one to choose it.\n\nWhen the game says Listen, stop and listen. Something is about to happen.\n\nSome moments are timed: you'll need to tell which side a sound came from. You can turn on extra time in Settings.\n\nSometimes the right move is to do nothing at all. If the game tells you not to touch anything, don't.\n\nTo pause, use the Pause button at the top of the screen, or double-tap anywhere with two fingers. Pausing freezes everything, even timed moments. If you leave the app, the game pauses by itself.\n\nIf you die, you go back to the last checkpoint. The main menu can always continue from where you stopped.", [
            Choice("Back", to("title")),
        ])
    }

    scene("check") {
        checkSide = Math.random() < 0.5 ? -1 : 1
        show("Headphone check", "Put your headphones on now. You'll hear a drop of water in one ear. Which ear?", [
            Choice("Left ear") { checkAnswer(-1) },
            Choice("Right ear") { checkAnswer(1) },
            Choice("Play the sound again") { drip(checkSide * 2) },
        ])
        after(4500) { drip(checkSide * 2) }
    }

    scene("endings") {
        menuMusic()
        let list = ENDINGS.map { e in (endings.includes(e.0) ? e.1 : "Not found yet") + " (" + e.2 + ")" }.join("\n")
        show("Endings", "You've found " + str(endings.length) + " of " + str(ENDINGS.length) + " endings.\n\n" + list, [
            Choice("Back", to("title")),
        ])
    }

    scene("tapes") {
        menuMusic()
        let ids = ["t1", "t2", "t3", "t4"]
        var choices = ids.filter { tapesFound.includes($0) }.map { t in Choice("Play: " + TAPES[t]) { try await tape(t) } }
        choices.append(Choice("Back", to("title")))
        show("Hidden tapes", tapesFound.length > 0 ? "Tapes you've found. They're hidden in Chapters Six, Seven, Eight and Ten." : "You haven't found any hidden tapes yet. They're hidden in Chapters Six, Seven, Eight and Ten. Look for choices that let you search.", choices)
    }

    scene("credits") {
        show("Credits", CREDITS, [Choice("Back", to("title"))])
    }
}
