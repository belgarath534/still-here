import Foundation

// The scene machinery. Everything here runs on the main thread.

/// The sound system. The app replaces this with the AVAudioEngine one at launch.
var audio: AudioBackend = SilentAudio()
/// The screen. The app's SwiftUI model registers itself here.
weak var view: GameView?
/// Tests run the game faster than real time.
var timeScale = 1.0

/* ---------- screens ---------- */

struct Choice {
    let label: String
    let act: @MainActor () async throws -> Void
    init(_ label: String, _ act: @escaping @MainActor () async throws -> Void) { self.label = label; self.act = act }
}
enum Panel { case settings }
enum Mode { case splash, menu, game }
struct Screen {
    var id = 0
    var title = ""
    var text = ""
    var choices: [Choice] = []
    var panel: Panel? = nil
    var mode = Mode.splash
    var dark = false
}
protocol GameView: AnyObject {
    func render(_ s: Screen)
    func announce(_ msg: String)
    func flash()
    /// A real system alert with an OK button, then `then` runs.
    func contentNote(_ msg: String, then: @escaping () -> Void)
    func pauseChanged(_ paused: Bool)
}

var screen = Screen()
func render() { view?.render(screen) }

func show(_ title: String, _ text: String, _ choices: [Choice] = [], _ panel: Panel? = nil) {
    screen.id += 1
    screen.title = title
    screen.text = text
    screen.choices = choices
    screen.panel = panel
    render()
}
func listening() { show("", "Listen.", []) }
/// Spoken by VoiceOver without moving focus.
func say(_ msg: String) { view?.announce(msg) }

/// Called by the UI when a choice is activated.
func choose(_ index: Int, screenID: Int) {
    guard screenID == screen.id, index < screen.choices.count, !paused else { return }
    if screen.mode == .menu { uiClick() }
    spawn(screen.choices[index].act)
}

/* ---------- settings and progress ---------- */

struct Settings: Codable {
    var extraTime = false, soft = false, hard = false
    var master = 1.0, musicVol = 1.0
    var haptics = true
}
var opts = Settings()
var done: [Double] = []
var endings: [String] = []
var tapesFound: [String] = []
var checkpoint: String? = nil
var toldTruth = 0.0, closeness = 0.0

private let defaults = UserDefaults.standard
private func readJSON<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
    guard let s = defaults.string(forKey: key), let d = s.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(type, from: d)
}
private func writeJSON<T: Encodable>(_ key: String, _ v: T) {
    if let d = try? JSONEncoder().encode(v), let s = String(data: d, encoding: .utf8) { defaults.set(s, forKey: key) }
}
struct StoryState: Codable { var toldTruth = 0.0, closeness = 0.0 }

func loadProgress() {
    opts = readJSON("stillhere-opts", Settings.self) ?? Settings()
    done = readJSON("stillhere-done", [Double].self) ?? []
    endings = readJSON("stillhere-endings", [String].self) ?? []
    tapesFound = readJSON("stillhere-tapes", [String].self) ?? []
    checkpoint = defaults.string(forKey: "stillhere-checkpoint")
    let st = readJSON("stillhere-story", StoryState.self) ?? StoryState()
    toldTruth = st.toldTruth; closeness = st.closeness
    dannyKept = defaults.string(forKey: "stillhere-danny") == "1"
}
func saveOpts() { writeJSON("stillhere-opts", opts) }
func saveStory() { writeJSON("stillhere-story", StoryState(toldTruth: toldTruth, closeness: closeness)) }
func markDone(_ n: Double) {
    saveStory()
    if !done.includes(n) { done.push(n) }
    writeJSON("stillhere-done", done)
}
func markEnding(_ id: String) {
    if !endings.includes(id) { endings.push(id) }
    writeJSON("stillhere-endings", endings)
}
func saveDanny() { defaults.set(dannyKept ? "1" : "0", forKey: "stillhere-danny") }
func resetProgress() {
    checkpoint = nil; done = []; endings = []; tapesFound = []
    for k in ["stillhere-checkpoint", "stillhere-done", "stillhere-endings", "stillhere-tapes"] { defaults.removeObject(forKey: k) }
}
func hardOr(_ normal: Double, _ hard: Double) -> Double { opts.hard ? hard : normal }

let ENDINGS: [(String, String, String)] = [
    ("alone", "Alone", "Chapter Two"), ("lockedin", "Locked In", "Chapter Three"), ("escape", "Escape", "Chapter Four"), ("shed", "The Shed", "Chapter Five"),
    ("together", "Together", "Chapter Twelve"), ("promise", "The Promise", "Chapter Twelve"), ("itwins", "It Wins", "Chapter Twelve"), ("silence", "Silence", "Chapter Twelve"),
    ("unrecorded", "Unrecorded", "Chapter Sixteen"), ("echo", "Echo", "Chapter Sixteen"),
]
let TAPES: Lookup<String> = ["t1": "The sheriff's case file", "t2": "The girl, whispering", "t3": "The DJ's private note", "t4": "Walter's warning"]
func findTape(_ id: String) {
    if !tapesFound.includes(id) { tapesFound.push(id) }
    writeJSON("stillhere-tapes", tapesFound)
    say("Hidden tape found: " + TAPES[id] + ". " + str(tapesFound.length) + " of 4.")
}

/* ---------- timers ---------- */
// Every scene, timer and choice runs as a "job". Leaving a scene cancels all of them,
// except the job doing the leaving, which carries on (just like the web version's timers).

enum JobID { @TaskLocal static var current: Int? }
private var jobs: [Int: Task<Void, Never>] = [:]
private var jobSeq = 0
var paused = false

func nowMs() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }

func spawn(_ fn: @escaping @MainActor () async throws -> Void) {
    jobSeq += 1
    let id = jobSeq
    jobs[id] = Task { @MainActor in
        await JobID.$current.withValue(id) {
            do { try await fn() } catch {}
        }
        jobs[id] = nil
    }
}
/// Cancel every pending timer, except the one that's asking.
func cancelTimers() {
    let me = JobID.current
    for (id, t) in jobs where id != me { t.cancel(); jobs[id] = nil }
}
/// Waits game time: frozen while paused, sped up in tests.
@MainActor func wait(_ ms: Double) async throws {
    var left = ms
    var last = nowMs()
    while left > 0 {
        let step = Swift.min(left / timeScale, 50)
        try await Task.sleep(nanoseconds: UInt64(Swift.max(step, 0.5) * 1_000_000))
        let n = nowMs()
        if !paused { left -= (n - last) * timeScale }
        last = n
    }
}
func after(_ ms: Double, _ fn: @escaping @MainActor () async throws -> Void) {
    spawn { try await wait(ms); try await fn() }
}

/// Repeating background things (heartbeat, birds, fire crackle) that keep going across scenes.
private var loops: [String: Task<Void, Never>] = [:]
func loop(_ key: String, _ fn: @escaping @MainActor () async throws -> Void) {
    loops[key]?.cancel()
    loops[key] = Task { @MainActor in do { try await fn() } catch {} }
}
func stopLoop(_ key: String) { loops[key]?.cancel(); loops[key] = nil }
/// Real-time sleep for loops; they check `paused` themselves.
@MainActor func sleepMs(_ ms: Double) async throws {
    try await Task.sleep(nanoseconds: UInt64(Swift.max(ms / timeScale, 0.5) * 1_000_000))
}

/* ---------- scenes ---------- */

struct SceneDef { let fn: @MainActor () async throws -> Void; let checkpoint: Bool }
var SCENES: [String: SceneDef] = [:]
func scene(_ id: String, _ checkpoint: Bool = false, _ fn: @escaping @MainActor () async throws -> Void) {
    SCENES[id] = SceneDef(fn: fn, checkpoint: checkpoint)
}
func to(_ id: String) -> @MainActor () async throws -> Void { { go(id) } }

let MENUS: Set<String> = ["splash", "title", "chapters", "settings", "howto", "credits", "reset", "check", "endings", "tapes"]

func clearScene() {
    cancelTimers()
    stopAll(false)
    birds(false)
}

var alertNoted = false
let ALERT_NOTE = "Content note: the next chapter includes a simulated emergency alert sound and message. It is part of the game. It is not a real alert, and nothing is happening in the real world."

func go(_ target: String?) {
    let id = target ?? "s1"
    if id == "c14" && !alertNoted {
        alertNoted = true
        clearScene()
        show("", "Content note.", [])
        if let v = view { v.contentNote(ALERT_NOTE) { go("c14") } } else { go("c14") }
        return
    }
    if let key = chapterKey(id), !chLoaded.contains(key) {
        clearScene()
        show("", "Loading…", [])
        spawn {
            if await loadChapter(key) { go(id) }
            else { show("", "Some sounds failed to load.", [Choice("Try again") { go(id) }, Choice("Main menu", to("title"))]) }
        }
        return
    }
    clearScene()
    guard let s = SCENES[id] else { return }
    currentScene = id
    if s.checkpoint {
        checkpoint = id
        UserDefaults.standard.set(id, forKey: "stillhere-checkpoint")
    }
    screen.dark = false
    screen.mode = id == "splash" ? .splash : MENUS.contains(id) ? .menu : .game
    spawn(s.fn)
    if !MENUS.contains(id) && !QUIET.contains(id) {
        if let cue = SCENE_MUSIC[id] { after(1200) { music(cue.0, cue.1, 4) } }
        after(2500) {
            let bed = BED[bedKey(id)]
            if musicNow == nil, let bed { music(bed, 0.12, 5) }
        }
    }
}
var currentScene = "splash"

/* ---------- death ---------- */
func die(_ text: String, whisper: Bool = true) {
    clearScene()
    silenceAll()
    show("", "", [])
    let t0 = whisper ? 1700.0 : 0
    if t0 > 0 { play("found", [.x(0.35), .z(0.2), .gain(1.6)]) }
    after(t0) { scream() }
    after(t0 + 2600) {
        show("It found you", text, [
            Choice("Try again from the last checkpoint") { go(checkpoint) },
            Choice("Main menu", to("title")),
        ])
    }
}

/* ---------- pause ---------- */
func openPause() {
    if paused || screen.mode != .game { return }
    paused = true
    audio.suspend()
    view?.pauseChanged(true)
}
func closePause(_ then: String? = nil) {
    guard paused else { return }
    paused = false
    audio.resume()
    view?.pauseChanged(false)
    if let then { go(then) }
}

/* ---------- sound loading ---------- */
// The first five chapters' sounds load at start; later chapters load their own and free the previous one's.
let SFX = ["awake","breath","comeout","creak","found","heart","hello","knock","neighbor","phone","scratch","scream","steps","stillhere",
  "jess_call","jess_code","jess_real","jess_car","me","thanks","jess_scream",
  "gravel0","gravel1","gravel2","tap0","tap1","glassbang","lock","unlock","keys","trunk","seat","rainloop","thunder",
  "news","j_incar","j_gas","j_lock","j_heard","j_made","j_hear",
  "trainhorn","trainhorn2","trainrumble","dooropen","c4_still","c4_plan","c4_walk","c4_gone","c4_fakejess","c4_alvarez","c4_you","news2",
  "vent0","vent1","vent2","conc0","conc1","conc2","doorclose",
  "i_cop1","i_cop2","i_cop3","i_cop4","i_disp1","i_disp2","i_disp3","i_r1","i_r2","i_r3","i_r4","i_r5","i_r6","i_r7","i_r8","i_r9","i_r10","i_r11","i_r12","i_r13","i_p1","i_j1","i_j2",
  "chop","c5_arrive","c5_aunt","c5_glad","c5_secret","c5_love","c5_storm","c5_fake","c5_deflect","c5_river","c5_sparrow","c5_lantern","c5_realknock","c5_shed","c5_together","c5_learning"]
let CH_SFX: [String: [String]] = [
  "c6": ["c6_door","c6_box","c6_sheriff","c6_girl","c6_dj1","c6_dj2","c6_dj3","c6_walter1","c6_walter2","c6_jess","c6_end","t4"],
  "c7": ["c7_jess1","c7_ruiz1","c7_djloop","c7_ruiz2","c7_jess2","c7_cr","t3","metalstep","c6_dj2"],
  "c8": ["c8_nurse1","c8_alv1","c8_jessq","c8_alv2","c8_alv3","c8_jess2","c8_nurse2","c8_fakealv","c8_alv4","t1","metalstep"],
  "z": ["i2_bro1","i2_ruiz1","i2_bro2","i2_kid","i2_disp","i2_ruiz2"],
  "c9": ["c9_call1","c9_call2","c9_found","c9_ruiz","c9_crruiz","c9_mine"],
  "c10": ["c10_jess1","c10_walter","c10_cr","c10_jess2","t2","metalstep","c6_dj2","c6_girl"],
  "c11": ["c11_jess1","c11_jess2","c11_jess3","c11_cr"],
  "c12": ["c12_jess1","c12_cr1","c12_crlove","c12_jesslove","c12_crdie","c12_jessalone","c12_ruiz","c12_news1","c12_news2","c12_jessend","c6_dj2","c6_girl","c9_crruiz","c8_fakealv","c11_cr"],
  "c13": ["a13_moving","a13_asst","a13_lights","a13_ruiz","a13_quiet","a13_news","a13_call","plate"],
  "c14": ["a14_twovoice","a14_safe","a14_alert","a14_glitch","a14_unlock","a14_jessunlock","a14_crunlock","a14_sang","c8_fakealv"],
  "c15": ["a15_call","a15_doors","a15_danny","a15_keep","a15_letgo","a15_cr","c6_girl","c6_dj2","c6_walter1"],
  "c16": ["a16_plan","a16_tower","a16_beg","a16_forget","a16_who","a16_say","a16_there","a16_ruizend","a16_news","a13_asst","a15_danny","c8_alv1","c11_cr"],
  "tapes": ["t1","t2","t3","t4"],
]
var chLoaded: Set<String> = []
var bootLoaded = false
func chapterKey(_ id: String) -> String? {
    if id.hasPrefix("c"), let n = Int(id.dropFirst().prefix(while: { $0.isNumber })), n >= 6 { return "c\(n)" }
    if id.hasPrefix("z") { return "z" }
    if id == "tapes" { return "tapes" }
    return nil
}
@MainActor func loadChapter(_ key: String) async -> Bool {
    for k in chLoaded where k != key && k != "tapes" {
        // keep anything the boot set also needs
        audio.unload(CH_SFX[k]!.filter { !SFX.contains($0) && !(CH_SFX[key] ?? []).contains($0) })
        chLoaded.remove(k)
    }
    guard await audio.load(CH_SFX[key]!) else { return false }
    chLoaded.insert(key)
    return true
}
@MainActor func loadSounds() async -> Bool {
    if bootLoaded { return true }
    bootLoaded = await audio.load(SFX)
    return bootLoaded
}
func len(_ name: String) -> Double { (audio.duration(name) ?? 3) * 1000 }
func has(_ name: String) -> Bool { audio.duration(name) != nil }

/* ---------- music ---------- */
var musicNow: String? = nil
func music(_ name: String, _ vol: Double = 0.35, _ fade: Double = 3) {
    var v = vol
    if (name == "m_drone" || name == "m_air") && screen.mode == .game { v = Swift.max(v, 0.13) }
    musicNow = v > 0 ? name : nil
    audio.music(name, vol: v, fade: fade)
}
func musicCut() { musicNow = nil; audio.musicCut() }

// every chapter has a bed track, and the tense scenes get their own
let BED: [String: String] = ["s": "m_child", "c2": "m_ghost", "c3": "m_gloom", "c4": "m_gloom", "i": "m_gloom", "c5": "m_haze", "c6": "m_ghost", "c7": "m_gloom", "c8": "m_child", "z": "m_ghost",
  "c9": "m_haze", "c10": "m_haze", "c11": "m_haze", "c12": "m_haze", "c13": "m_rest", "c14": "m_gloom", "c15": "m_ghost", "c16": "m_child", "e": "m_child"]
func bedKey(_ id: String) -> String {
    if id.hasPrefix("c"), let n = Int(id.dropFirst().prefix(while: { $0.isNumber })) { return "c\(n)" }
    return String(id.prefix(1))
}
let SCENE_MUSIC: [String: (String, Double)] = [
  "s4": ("m_gloom", 0.12), "s5": ("m_child", 0.1), "s7": ("m_gather", 0.14), "s7b": ("m_gather", 0.14),
  "c2visit": ("m_gloom", 0.12), "c2quiet": ("m_gloom", 0.1),
  "c3radio": ("m_ghost", 0.12), "c3off": ("m_ghost", 0.12), "c3trunk": ("m_ghost", 0.12), "c3gas": ("m_gloom", 0.12), "c3return": ("m_gather", 0.14), "c3drive": ("m_volatile", 0.16),
  "c4plan": ("m_gloom", 0.12), "c4sneak": ("m_gather", 0.12), "c4out": ("m_gather", 0.14), "c4plea": ("m_gather", 0.15), "c4train": ("m_volatile", 0.18),
  "i2": ("m_gloom", 0.13), "i3": ("m_gloom", 0.13), "iq": ("m_gloom", 0.13), "itape": ("m_gloom", 0.12), "idoor": ("m_gather", 0.13), "i5": ("m_gather", 0.14),
  "icell": ("m_ghost", 0.12), "icall": ("m_ghost", 0.12), "iradio": ("m_gloom", 0.12), "i6": ("m_volatile", 0.15), "i6b": ("m_child", 0.12),
  "c5storm": ("m_gather", 0.14), "c5door": ("m_gloom", 0.12), "c5shed": ("m_haze", 0.12),
  "c6box": ("m_ghost", 0.1), "c6night": ("m_child", 0.12),
  "c7stairs": ("m_gather", 0.13), "c7booth": ("m_gloom", 0.12),
  "c8room": ("m_child", 0.12), "c8truth": ("m_gloom", 0.13), "c8stairs": ("m_volatile", 0.15), "c8vent": ("m_gather", 0.14),
  "z2": ("m_ghost", 0.12), "z3": ("m_gloom", 0.12),
  "c9run": ("m_volatile", 0.14), "c9found": ("m_ghost", 0.12), "c10room": ("m_haze", 0.13), "c11split": ("m_gather", 0.13), "c12starve": ("m_haze", 0.1),
  "c14door": ("m_gather", 0.15), "c15b": ("m_ghost", 0.12), "c16last": ("m_haze", 0.12),
]
let QUIET: Set<String> = ["c11", "c12silence", "c16unrecorded", "check"]
