import Foundation

// Stranded: a survival mode played as Jess, after the story. The ferry goes down in a storm and she
// washes up alone on an island. By day you choose what to do (water, food, wood, shelter, a signal
// fire on the hill); by night you listen. Something on the island has learned voices too.
// Each night at the fire, Jess remembers: her parents, and the aunt who raised her.
//
// Jess's lines are recorded in her own voice as st_v_<key>.mp3 (ElevenLabs, like the story). Until
// they are, ST_VOICE_READY stays false and her words are shown and read by VoiceOver.

let ST_VOICE_READY = false

let ST_SFX = ["st_ocean", "st_crickets", "st_fire", "st_sink", "st_drown", "st_chop", "st_drink", "st_wade", "st_splash0", "st_splash1",
              "st_nightbird", "st_frog"] + (0..<4).map { "st_wave\($0)" } + (0..<6).map { "st_gull\($0)" } + (0..<6).map { "st_sand\($0)" }

/// Everything said in Stranded. `who`: jess, or tia (the thing in the water, using her aunt's voice).
let ST_LINES: [(key: String, who: String, text: String)] = [
    // waking up
    ("wake", "jess", "Okay. Okay. Breathe, Jess. You're alive. You're on a beach. The ferry is... the ferry is gone. Tía always said, when you're scared, talk out loud. So I'm talking."),
    // memories, one each night
    ("mem1", "jess", "I was six. Mom and Dad went out for their anniversary. It was raining, like that night at the motel. The phone rang at two in the morning, and I remember the sound Tía made. Not a scream. Just air going out of her."),
    ("mem2", "jess", "She came to get me in her nightgown and a raincoat. She didn't let go of my hand for a week. Not in the hospital, not at the funeral, not in the car. I think she was scared that if she let go, I'd go too."),
    ("mem3", "jess", "She raised me in that little blue house. She worked nights at the laundry, and every night before she left, she sang me the sparrow song. Little sparrow, don't you cry, the dark is just the day asleep. I hated it when I was twelve. I'd give anything to hear it now."),
    ("mem4", "jess", "When I was fifteen, I ran away. Got as far as the bus station. I was so angry. At Mom and Dad for dying, at her for not being them. She found me at four in the morning. She didn't yell. She sat down next to me and said, mija, you can be angry. Just be angry at home."),
    ("mem5", "jess", "That's why I came back for you. At the motel. Everyone thinks I'm brave. I'm not. I just know what it's like to be the one left behind, and I'm not doing that to anybody. Ever."),
    ("mem6", "jess", "When it took her, that week in Elk Ridge, it learned her voice by making her talk. Every night, in the dark. I keep thinking: what did she tell it? Did she tell it about me? Is that how it knew my name?"),
    ("mem7", "jess", "If someone finds this beach and I'm not here... Tía, I'm sorry I never called enough. And to you, at home: you never asked about my family. I liked that you never asked. I was going to tell you all of it. I still am."),
    // days
    ("water", "jess", "Rainwater, in the curve of a palm leaf. Tastes like dirt. Best thing I've ever had."),
    ("fish", "jess", "Got one! Okay, it's tiny. It's a tiny, ugly fish. It's dinner."),
    ("nofish", "jess", "Nothing. They're laughing at me down there, I know it."),
    ("wood", "jess", "Driftwood. Dry on top. Tía would say, a fire is a friend you have to feed."),
    ("shelter", "jess", "It's a roof. It's a terrible roof. But it's mine."),
    ("signal", "jess", "Another pile on the hill. If anyone sails past at night, they'll see it. They have to."),
    ("wreck", "jess", "Bits of the ferry, all along the rocks. A life vest. Somebody's shoe. Don't think about it. Just look for anything useful."),
    ("boat", "jess", "Is that... an engine? That's an engine! The signal fire, now, now, now!"),
    ("nowood", "jess", "No! No dry wood! Come back! Please come back!"),
    // nights
    ("tia1", "tia", "Mija... come in. The water's warm. I'm right here. I came all this way for you."),
    ("tia2", "tia", "Little sparrow, don't you cry... come in, mija. Come home."),
    ("notTia", "jess", "Tía is in a hospital bed three thousand miles away. That isn't her. That is not her."),
    ("steps", "jess", "Someone's walking around the fire. Don't move. Don't breathe."),
    ("storm", "jess", "The wind's taking everything. I can only hold on to one thing."),
    ("whisper", "jess", "It's in the trees, saying my name. Jessica. Nobody calls me Jessica."),
    // endings
    ("rescued", "jess", "They're real. They're real! Their boots are wet and they're shouting and they smell like diesel and they're real. Take me home. Please. Someone's waiting for me."),
    ("drowned", "jess", "Tía? Tía, it's so cold..."),
    ("faded", "jess", "I'm just going to close my eyes for a minute. Just a minute."),
]
func stLine(_ key: String) -> (who: String, text: String) {
    let l = ST_LINES.first { $0.key == key }!
    return (l.who, l.text)
}
/// Jess's words for the screen, in quotes.
func stQuote(_ key: String) -> String { "“" + stLine(key).text + "”" }

/// Plays a line in its recorded voice (once recorded); the text is on screen either way.
@MainActor func stSay(_ key: String, _ o: [O] = []) async throws {
    let name = "st_v_" + key
    guard ST_VOICE_READY, has(name) else { return }
    let who = stLine(key).who
    play(name, (who == "tia" ? [.x(0), .z(-7), .lowpass(2500), .gain(1.3)] : [.x(-0.2), .z(-0.4), .gain(1.3)]) + o)
    try await wait(len(name) + 300)
}

/* ---------- the state of things ---------- */

var stDay = 0, stActions = 3
var stWater = 70.0, stFood = 70.0, stWarmth = 60.0
var stWood = 0, stShelter = 0, stSignal = 0
var stWreck = ["bottle", "tin", "tarp", "lighter"]
var stMem = 0, stStorm = false, stLastNight = ""
/// days the boat has been looked for since the signal fire was finished
var stBoatChance = 0.0
/// what the night's choice is waiting for, for the play-test bots
var stLive = false, stSide = 0.0
var stBestDays: Int {
    get { UserDefaults.standard.integer(forKey: "stillhere-stbest") }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-stbest") }
}
var stRescued: Bool {
    get { UserDefaults.standard.bool(forKey: "stillhere-strescued") }
    set { UserDefaults.standard.set(newValue, forKey: "stillhere-strescued") }
}

let SHELTERS = ["no shelter", "a frame of branches", "a roof of palm leaves", "walls against the wind"]

func stStatus() -> String {
    "Water " + str(Int(stWater)) + ". Food " + str(Int(stFood)) + ". Warmth " + str(Int(stWarmth)) + ". Wood: " + str(stWood) + ". Shelter: " + SHELTERS[stShelter] + ". Signal fire: " +
        (stSignal >= 3 ? "ready on the hill." : str(stSignal) + " of 3 piles.")
}
private func clamp(_ v: Double) -> Double { Swift.min(Swift.max(v, 0), 100) }

/* ---------- sound ---------- */

private func flatLoop() -> PlayParams { var p = PlayParams(); p.spatial = false; p.loop = true; p.keep = true; return p }
func stOcean(_ level: Double) { audio.setBed("st_ocean", .named("st_ocean"), flatLoop(), gain: level, fade: 3) }
func stCrickets(_ level: Double) { audio.setBed("st_crickets", .named("st_crickets"), flatLoop(), gain: level, fade: 3) }
func stFire(_ level: Double) {
    var p = flatLoop(); p.spatial = true; p.x = 0.6; p.y = -0.4; p.z = -1.2
    audio.setBed("st_fire", .named("st_fire"), p, gain: level, fade: 2)
}
/// gulls and waves, now and then
func stDaySounds(_ on: Bool) {
    stopLoop("st_day")
    if !on { return }
    loop("st_day") {
        while true {
            if !paused {
                if Math.random() < 0.5 { play("st_gull" + str(Int(Math.random() * 6)), [.x(Math.random() * 10 - 5), .y(3), .z(-4 - Math.random() * 4), .gain(0.6)]) }
                else { play("st_wave" + str(Int(Math.random() * 4)), [.x(Math.random() * 6 - 3), .z(-6), .gain(0.7)]) }
            }
            try await sleepMs(2500 + Math.random() * 4000)
        }
    }
}
private func sandSteps(_ n: Int, _ list: [O] = []) {
    for i in 0..<n { play("st_sand" + str(i % 6), [.y(-1.3), .z(-0.2), .gain(0.7), .delay(Double(i) * 0.42)] + list) }
}
func stQuiet() { stOcean(0); stCrickets(0); stFire(0); stDaySounds(false); rain(0); wind(0); engine(0) }

/* ---------- days ---------- */

func stNewGame() {
    stDay = 0; stWater = 70; stFood = 70; stWarmth = 60; stWood = 0; stShelter = 0; stSignal = 0
    stWreck = ["bottle", "tin", "tarp", "lighter"]; stMem = 0; stStorm = false; stLastNight = ""; stBoatChance = 0
    go("w_wake")
}

/// The next part of the day, or evening once the actions are used up.
@MainActor func stDayScreen(_ result: String) {
    if stActions <= 0 { go("w_evening"); return }
    let part = stActions == 3 ? "morning" : stActions == 2 ? "midday" : "afternoon"
    var choices: [Choice] = []
    // once the signal fire is ready, a boat may pass: listen for it
    if stSignal >= 3 && Math.random() < stBoatChance {
        stBoatChance = 0
        choices.append(Choice("Light the signal fire!") { try await stLightSignal() })
        engine(0.08)
        show("Day " + str(stDay) + ", " + part, result + (result.isEmpty ? "" : "\n\n") + "Far out on the water: the low drone of an engine.\n\n" + stQuote("boat"), choices + stActionChoices())
        spawn { try await stSay("boat") }
        return
    }
    engine(0)
    show("Day " + str(stDay) + ", " + part, (result.isEmpty ? "" : result + "\n\n") + stStatus(), stActionChoices())
}

private func stActionChoices() -> [Choice] {
    var c: [Choice] = [
        Choice("Look for fresh water") { try await stAct("water") },
        Choice("Fish in the shallows") { try await stAct("fish") },
        Choice("Gather driftwood") { try await stAct("wood") },
    ]
    if stShelter < 3 { c.append(Choice("Work on the shelter (2 wood)") { try await stAct("shelter") }) }
    if stSignal < 3 { c.append(Choice("Stack the signal fire on the hill (3 wood)") { try await stAct("signal") }) }
    if !stWreck.isEmpty { c.append(Choice("Search the wreckage on the rocks") { try await stAct("wreck") }) }
    return c
}

@MainActor func stAct(_ what: String) async throws {
    clearScene(); listening()
    var result = ""
    switch what {
    case "water":
        sandSteps(6)
        try await wait(2600)
        play("st_drink", [.z(-0.5), .gain(1)])
        let got = stStorm ? 55.0 : 40.0
        stWater = clamp(stWater + got)
        try await stSay("water")
        result = (stStorm ? "Last night's storm filled every leaf and shell. " : "") + "You find rainwater caught in palm leaves and drink until you can't. Water +" + str(Int(got)) + ".\n\n" + stQuote("water")
    case "fish":
        play("st_wade", [.z(-1), .gain(1)]); play("st_wade", [.x(0.4), .z(-1.2), .delay(1.2)])
        try await wait(2400)
        play("st_splash" + str(Int(Math.random() * 2)), [.x(0.3), .z(-1), .gain(1.1)])
        try await wait(1200)
        if Math.random() < 0.7 {
            stFood = clamp(stFood + 35)
            try await stSay("fish")
            result = "An hour in the shallows with a sharpened stick. Food +35.\n\n" + stQuote("fish")
        } else {
            try await stSay("nofish")
            result = "An hour in the shallows. Nothing.\n\n" + stQuote("nofish")
        }
    case "wood":
        sandSteps(8)
        try await wait(3000)
        play("st_chop", [.x(0.3), .z(-0.8), .gain(1)]); play("st_chop", [.x(0.3), .z(-0.8), .gain(1), .delay(1.1)])
        try await wait(2300)
        let n = 2 + (Math.random() < 0.4 ? 1 : 0)
        stWood += n
        try await stSay("wood")
        result = "You drag " + str(n) + " pieces of driftwood up above the tide line. Wood: " + str(stWood) + ".\n\n" + stQuote("wood")
    case "shelter":
        if stWood < 2 { stDayScreen("You need 2 pieces of wood for the shelter. You have " + str(stWood) + "."); return }
        stWood -= 2; stShelter += 1
        for i in 0..<3 { play("st_chop", [.x(-0.4), .z(-0.8), .gain(1), .delay(Double(i) * 0.9)]) }
        try await wait(3200)
        try await stSay("shelter")
        result = "Your shelter now has " + SHELTERS[stShelter] + ". Nights will be warmer.\n\n" + stQuote("shelter")
    case "signal":
        if stWood < 3 { stDayScreen("You need 3 pieces of wood for the signal fire. You have " + str(stWood) + "."); return }
        stWood -= 3; stSignal += 1
        sandSteps(10, [.gain(0.5)])
        try await wait(4400)
        try await stSay("signal")
        result = stSignal >= 3 ? "The signal fire is ready on the hill. Now listen for boats.\n\n" + stQuote("signal") : "Pile " + str(stSignal) + " of 3 on the hill.\n\n" + stQuote("signal")
        if stSignal >= 3 { stBoatChance = 0.35 }
    default: // the wreckage
        play("st_wave" + str(Int(Math.random() * 4)), [.x(1), .z(-2)])
        sandSteps(5, [.x(0.5)])
        try await wait(2600)
        let item = stWreck.removeFirst()
        if stWreck.count == 3 { try await stSay("wreck") }
        switch item {
        case "bottle": stWater = clamp(stWater + 30); result = "Wedged between two rocks: a sealed bottle of water. Water +30."
        case "tin": stFood = clamp(stFood + 30); result = "A tin of peaches from the ferry's galley, dented but whole. Food +30."
        case "tarp": stShelter = Swift.min(stShelter + 1, 3); result = "A torn tarp from a lifeboat. It goes straight over your shelter: " + SHELTERS[stShelter] + "."
        default: stWood += 2; result = "A broken oar and a coil of dry rope from a lifeboat. Good fuel. Wood +2."
        }
        if stWreck.count == 3 { result = stQuote("wreck") + "\n\n" + result }
        if stWreck.isEmpty { result += " There's nothing else worth taking from the rocks." }
    }
    stActions -= 1
    stDaySounds(true)
    stDayScreen(result)
}

/// The boat. Light the fire and you're saved.
@MainActor func stLightSignal() async throws {
    clearScene(); listening()
    if stWood < 1 {
        try await stSay("nowood")
        engine(0)
        stActions -= 1
        stDayScreen("You have no dry wood to light it with. The engine fades into the distance.\n\n" + stQuote("nowood") + "\n\nKeep some wood back for next time.")
        return
    }
    stWood -= 1
    sandSteps(14, [.gain(0.6)])
    try await wait(5000)
    stFire(0.9)
    try await wait(2500)
    engine(0.25)
    try await wait(2500)
    go("w_rescued")
}

/* ---------- nights ---------- */

/// One encounter, from the second night on, never the same twice running.
@MainActor func stNightEvent() async throws {
    var kinds = ["tia", "steps", "storm", "whisper"]
    kinds.removeAll { $0 == stLastNight }
    let k = pick(kinds)
    stLastNight = k
    stStorm = false
    switch k {
    case "tia":
        stLive = true
        play("st_wave0", [.z(-6), .gain(0.9)])
        let line = stDay >= 4 ? "tia2" : "tia1"
        try await stSay(line)
        show("Night " + str(stDay), "From the water, past the waves, a warm voice you know better than your own:\n\n" + stQuote(line) + "\n\n" + stQuote("notTia"), [
            Choice("Walk into the water") { stLive = false; go("w_drowned") },
            Choice("Stay by the fire") { stLive = false; stDawn("You sit with your back to the sea until it stops. In the morning, there are footprints in the wet sand. Coming out of the water. Going back in.") },
        ])
    case "steps":
        stLive = true
        try await stSay("steps")
        show("Night " + str(stDay), "Footsteps in the sand. Slow. Circling the fire.\n\n" + stQuote("steps") + "\n\nDon't press anything until they're gone.", [
            Choice("Grab a burning stick") { stLive = false; stStepsCaught() },
            Choice("Run for the trees") { stLive = false; stStepsCaught() },
        ])
        for i in 0..<14 {
            let a = Double(i) / 14 * Double.pi * 2
            play("st_sand" + str(i % 6), [.x(cos(a) * 2.5), .z(sin(a) * 2.5), .gain(0.8), .delay(1.5 + Double(i) * 0.7)])
        }
        after(1500 + 14 * 700 + 2000) { stLive = false; stDawn("The footsteps walk away, down to the water, and stop at the edge. You don't sleep.") }
    case "storm":
        stStorm = true
        wind(0.35); rain(0.5)
        play("thunder", [.z(-8), .x(pick([-5, 5])), .gain(0.9)])
        if stShelter >= 2 {
            show("Night " + str(stDay), "A storm comes in off the sea. The wind screams through the palms, but your shelter holds. You listen to the rain hammer the roof and stay dry.", [
                Choice("Wait for morning") { stDawn("The storm passes before dawn. Everything outside is soaked, and every leaf is full of rainwater.") },
            ])
            return
        }
        try await stSay("storm")
        show("Night " + str(stDay), "A storm comes in off the sea, and your shelter can't stop it.\n\n" + stQuote("storm"), [
            Choice("Shield the fire") { if stWood > 0 { stWood -= 1 }; stDawn("You keep the fire alive with your own body. Your spare wood is soaked through. Wood: " + str(stWood) + ".") },
            Choice("Shield the wood") { stWarmth = clamp(stWarmth - 25); stDawn("The fire drowns. You hold the wood to your chest all night, shaking. Warmth -25.") },
        ])
    default: // a whisper from one side of the treeline
        stLive = true
        stSide = pick([-1.0, 1])
        let side = stSide
        try await stSay("whisper")
        show("Night " + str(stDay), "Something in the trees is whispering your name.\n\n" + stQuote("whisper") + "\n\nThrow a burning branch at it.", [
            Choice("Throw it to the left") { stLive = false; stWhisper(side < 0) },
            Choice("Throw it to the right") { stLive = false; stWhisper(side > 0) },
        ])
        for i in 0..<4 { tone([.type("sawtooth"), .f(180 + Math.random() * 40), .dur(0.5), .gain(0.05), .x(side * 4), .z(-3), .delay(Double(i) * 1.1)]) }
        for i in 0..<3 { play("st_nightbird", [.x(side * 5), .z(-4), .rate(0.6), .gain(0.8), .delay(Double(i) * 1.5 + 0.4)]) }
    }
}
@MainActor private func stStepsCaught() {
    clearScene()
    stWarmth = clamp(stWarmth - 30); stWood = Swift.max(stWood - 2, 0)
    stFire(0)
    play("st_splash1", [.x(0.6), .z(-1.2), .gain(1.2)])
    stDawn("The moment you move, the footsteps stop. Then the fire goes out, kicked across the sand, and something runs, laughing, into the sea. Warmth -30, and two pieces of wood are gone.")
}
@MainActor private func stWhisper(_ right: Bool) {
    clearScene()
    if right {
        play("st_nightbird", [.x(stSide * 4), .z(-3), .rate(0.5), .gain(1.3)])
        stDawn("The branch lands, sparks fly, and something shrieks and crashes away through the trees. It doesn't come back tonight.")
    } else {
        stFood = clamp(stFood - 25)
        stDawn("The branch lands in empty sand. Behind you, on the other side, something drags your food into the dark. Food -25.")
    }
}

/// The end of a night: things get worse, someone might not wake up, otherwise a new day.
@MainActor func stDawn(_ what: String) {
    stWater = clamp(stWater - 30)
    stFood = clamp(stFood - 22)
    if stWater <= 0 || stFood <= 0 || stWarmth <= 0 { go("w_faded"); return }
    if stDay > stBestDays { stBestDays = stDay }
    if stSignal >= 3 { stBoatChance = Swift.min(stBoatChance + 0.3, 1) }
    show("Dawn", what + "\n\n" + stStatus(), [Choice("Get up") { go("w_day") }])
}

/* ---------- scenes ---------- */

func registerStranded() {
    scene("w_start") {
        stQuiet()
        stOcean(0.2)
        show("Stranded", "Play as Jess, after the story. A ferry, a storm, and then a beach. You're alone on an island, with what's left of the ferry on the rocks.\n\nBy day, choose how to spend your hours: water, food, wood, a shelter, and a signal fire on the hill. Keep an eye on your water, food and warmth. By night, listen. Something on this island has learned voices too.\n\nAnd every night at the fire, Jess remembers." +
            (stBestDays > 0 ? "\n\nYour longest: " + str(stBestDays) + (stBestDays == 1 ? " day." : " days.") + (stRescued ? " You've been rescued before." : "") : ""), [
            Choice("Begin") { stNewGame() },
            Choice("Back", to("modes")),
        ])
    }
    scene("w_wake") {
        stQuiet()
        listening()
        play("st_sink", [.z(-8), .gain(1.1)])
        try await wait(5000)
        stOcean(0.5)
        play("st_wave1", [.z(-1.5), .gain(1.2)])
        try await wait(2500)
        try await stSay("wake")
        stDaySounds(true)
        show("Washed up", "The last thing you remember is the ferry rolling over in the dark, and cold water, and a life vest pulling at your neck.\n\nNow: sand under your cheek. Sun. Gulls. The sea pulling at your feet.\n\n" + stQuote("wake"), [
            Choice("Get up") { go("w_day") },
        ])
    }
    scene("w_day") {
        stDay += 1
        stActions = 3
        stCrickets(0); stFire(0); rain(0); wind(0)
        stOcean(0.35)
        stDaySounds(true)
        music("m_haze", 0.1, 4)
        stDayScreen(stDay == 1 ? "The island is small: a beach, rocks where the ferry broke up, a hill, and thick trees behind it all. You have three good parts of the day before dark." : "")
    }
    scene("w_evening") {
        stDaySounds(false)
        stOcean(0.25)
        stCrickets(0.25)
        music("m_gloom", 0.1, 4)
        let shelterWarmth = Double(stShelter) * 10
        var c: [Choice] = []
        if stWood > 0 {
            c.append(Choice("Light the fire (1 wood)") {
                stWood -= 1
                stWarmth = clamp(60 + shelterWarmth)
                stFire(0.6)
                go("w_night")
            })
        }
        c.append(Choice(stWood > 0 ? "Save the wood and sit in the dark" : "Sit in the dark") {
            stWarmth = clamp(stWarmth - 35 + shelterWarmth)
            go("w_night")
        })
        show("Evening, day " + str(stDay), "The sun goes down fast here. The crickets start up all at once.\n\n" + stStatus() + (stWood == 0 ? "\n\nNo wood. Tonight will be cold." : ""), c)
    }
    scene("w_night") {
        listening()
        try await wait(1500)
        // a memory, every night until there are none left
        if stMem < 7 {
            stMem += 1
            let key = "mem" + str(stMem)
            try await stSay(key)
            show("Night " + str(stDay) + ": Jess remembers", stQuote(key), [
                Choice("Listen to the night") { try await stNightOrDawn() },
            ])
        } else { try await stNightOrDawn() }
    }
    scene("w_rescued") {
        stQuiet()
        engine(0.3)
        try await stSay("rescued")
        engine(0)
        stRescued = true
        if stDay > stBestDays { stBestDays = stDay }
        music("m_rest", 0.25, 3)
        show("Rescued", "A fishing boat sees the fire on the hill. Two men in yellow coats wade ashore, shouting in a language you don't speak, and wrap you in a blanket that smells of diesel.\n\n" + stQuote("rescued") + "\n\nJess survived " + str(stDay) + (stDay == 1 ? " day." : " days.") + (stMem < 7 ? "\n\nThere's more of her story she didn't get to tell. Stay longer next time." : ""), [
            Choice("Play again") { stNewGame() },
            Choice("Main menu", to("title")),
        ])
    }
    scene("w_drowned") {
        stQuiet()
        listening()
        play("st_wade", [.z(-1)]); play("st_wade", [.z(-2), .delay(1.4)])
        try await wait(3200)
        try await stSay("drowned")
        play("st_drown", [.z(-0.3), .gain(1)])
        try await wait(5500)
        show("The island keeps her", "The water is warm, like the voice said. That was the only true thing it said.\n\n" + stQuote("drowned") + "\n\nJess lasted " + str(stDay) + (stDay == 1 ? " day." : " days."), [
            Choice("Try again") { stNewGame() },
            Choice("Main menu", to("title")),
        ])
    }
    scene("w_faded") {
        stQuiet()
        stOcean(0.2)
        let why = stWater <= 0 ? "Thirst" : stFood <= 0 ? "Hunger" : "The cold"
        try await stSay("faded")
        show("The island keeps her", why + " wins, in the end. Not with a scream. Just quietly, in the morning, with the gulls.\n\n" + stQuote("faded") + "\n\nJess lasted " + str(stDay) + (stDay == 1 ? " day." : " days.") + " Water, food and warmth all have to last the night.", [
            Choice("Try again") { stNewGame() },
            Choice("Main menu", to("title")),
        ])
    }
}

@MainActor func stNightOrDawn() async throws {
    if stDay >= 2 { try await stNightEvent() }
    else { stDawn("Nothing but the sea, all night. You sleep in pieces.") }
}
