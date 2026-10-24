import Foundation

// The story's data tables, generated from the web version by tools/tables.js.

struct Question { let clip: String, title: String, text: String; let answers: [(String, Double)] }
let Q: [Question] = [
    Question(clip: "i_r1", title: "Interview Room B", text: "A small room. A metal table. Fluorescent lights buzzing overhead. A door opens, heavy footsteps, a chair scrapes.\n\nA tired, gravelly voice: “Sit down. I'm Detective Ruiz. Let's start simple. Whose car was that?”",
             answers: [("“It's Jess's car. She came to help me.”", 1), ("“I don't know.”", 0), ("Say nothing", 0)]),
    Question(clip: "i_r3", title: "Mrs. Alvarez", text: "“Your neighbor. Mrs. Alvarez. Nobody's seen her since Tuesday night. Her front door was standing wide open. And every mirror in her house had been covered with a towel.”",
             answers: [("“It took her. Whatever it is, it started with her.”", 1), ("“I don't know anything about that.”", 0)]),
    Question(clip: "i_r4", title: "The doors", text: "Ruiz leans in. “So tell me something. Why were all four doors locked?”",
             answers: [("“Because we locked something in there.”", 1), ("“I don't know.”", 0)]),
]

struct Plea { let clip: String; let z: Double; let opt: [O]; let text: String, death: String }
let PLEAS: [Plea] = [
    Plea(clip: "c4_fakejess", z: 4, opt: [.phone(true)],
         text: "You start walking. Behind you, from inside the car, Jess's voice. Sobbing. Screaming:\n\n“Let me out! Please! It's me, it's Jess! It tricked you, she's the one out there! Open the door!”\n\nBut Jess is right here. Her hand is in yours. It's shaking.",
         death: "You turn back. Jess screams your name and tries to hold on, but you pull free and unlock the door.\n\nThe real Jess was the one holding your hand."),
    Plea(clip: "c4_alvarez", z: 7, opt: [],
         text: "Further back now. A different voice through the glass. Mrs. Alvarez, crying:\n\n“Sweetheart? Sweetheart, please, it's so dark in here. I can't breathe. Please open the door, honey. Please.”",
         death: "You go back for her.\n\nThere was never anyone in that car but it."),
    Plea(clip: "c4_you", z: 10, opt: [],
         text: "And then, last of all, your own voice. Quiet. Reasonable. Almost kind:\n\n“Wait... don't leave me. I'm the real one. It's you that got out. You're the copy. Open the door... and see.”\n\nThe crossing bells are louder now. And far down the line: a train horn.",
         death: "You have to know. You go back, and you open the door, and you look inside.\n\nIt's wearing your face. It smiles. Now you'll never know which one of you walked away."),
]

struct Station { let clip: String, text: String }
let STATIONS: [Station] = [
    Station(clip: "c7_djloop", text: "The DJ, slow and wrong: “You're listening to K-R-O-D. It's two a.m. It's always two a.m. Caller, you're on the air.”"),
    Station(clip: "awake", text: "A whisper you know far too well: “I know you're awake.”"),
    Station(clip: "c5_love", text: "Jess, by the fire: “I love you. I know that's crazy.” The tower is broadcasting you."),
]

struct MineRoom { let title: String, text: String; let opts: [(String, Double)]; var voices = false }
let ROOMS: [MineRoom] = [
    MineRoom(title: "The shaft", text: "An old wooden ladder goes down into the black. Beside it, a frayed rope.",
             opts: [("Climb down the ladder (it creaks)", 3), ("Lower yourselves down the rope, slowly", 1)]),
    MineRoom(title: "The flooded tunnel", text: "The tunnel is flooded to your knees. A line of stepping stones runs along the wall.",
             opts: [("Wade through the water, one slow step at a time", 1), ("Jump from stone to stone", 3)]),
    MineRoom(title: "The radios", text: "The tunnel is full of old radios. Hundreds of them, piled to the ceiling. Every one of them was taken from a house in Elk Ridge.",
             opts: [("Step over the pile carefully", 2), ("Squeeze through the narrow gap along the wall", 0)]),
    MineRoom(title: "The voices", text: "A chamber where the air is warm. From the dark, voices murmur. Dozens. Everyone it ever took, still talking, very softly.\n\nOne voice, old and faint, is clearer than the rest.",
             opts: [("Just listen", 0), ("Answer the old man", 6)], voices: true),
]

struct Room4 { let label: String; let x: Double, z: Double }
let ROOMS4: [Room4] = [
    Room4(label: "Kitchen, to your left", x: -4, z: -1),
    Room4(label: "Bedroom, to your right", x: 4, z: -1),
    Room4(label: "Living room, ahead of you", x: 0, z: -5),
    Room4(label: "Hallway, behind you", x: 0, z: 4),
]

let BURN: [(String, String)] = [
    ("c6_girl", "The girl's interview"),
    ("c6_dj2", "The DJ's last broadcast"),
    ("c6_walter1", "Walter's confession"),
    ("neighbor", "An answering machine from Mrs. Alvarez's house"),
]

let DELETE: [(String, String, String)] = [
    ("c8_alv1", "Delete: voicemails from Mrs. Alvarez", "Mrs. Alvarez's voice, one last time: “Jessica? Is that you, mija?” Then nothing."),
    ("i_r13", "Delete: voice messages from Ruiz", "Ruiz, from months ago: “There's a cabin. My brother's.” Cut off mid-word."),
    ("c5_love", "Delete: every voice message from Jess", "Jess, by the fire, so long ago: “I love you. I know that's crazy.” Jess, beside you now, closes her eyes as it disappears."),
    ("a13_asst", "Delete: the smart speaker's voice history", "The cheerful assistant: “Hi there! I'm all set up.” A year of everything you ever said to it, gone."),
]

let SPELL: Lookup<String> = ["river": "R. I. V. E. R.", "sparrow": "S. P. A. R. R. O. W.", "lantern": "L. A. N. T. E. R. N."]

struct ChapterInfo { let n: Double; let id: String, name: String }
let CHAPTERS: [ChapterInfo] = [
    ChapterInfo(n: 1, id: "s1", name: "Chapter One: The House"),
    ChapterInfo(n: 2, id: "c2", name: "Chapter Two: The Motel"),
    ChapterInfo(n: 3, id: "c3", name: "Chapter Three: The Road"),
    ChapterInfo(n: 4, id: "c4", name: "Chapter Four: The Crossing"),
    ChapterInfo(n: 5, id: "i1", name: "Interlude: The Station"),
    ChapterInfo(n: 6, id: "c5", name: "Chapter Five: The Cabin"),
    ChapterInfo(n: 7, id: "c6", name: "Chapter Six: The Tapes"),
    ChapterInfo(n: 8, id: "c7", name: "Chapter Seven: The Radio Tower"),
    ChapterInfo(n: 9, id: "c8", name: "Chapter Eight: Mrs. Alvarez"),
    ChapterInfo(n: 10, id: "z1", name: "Interlude Two: Ruiz"),
    ChapterInfo(n: 11, id: "c9", name: "Chapter Nine: Separated"),
    ChapterInfo(n: 12, id: "c10", name: "Chapter Ten: The Hollow"),
    ChapterInfo(n: 13, id: "c11", name: "Chapter Eleven: Your Voice"),
    ChapterInfo(n: 14, id: "c12", name: "Chapter Twelve: Still Here"),
    ChapterInfo(n: 15, id: "c13", name: "Act Four. Chapter Thirteen: After"),
    ChapterInfo(n: 16, id: "c14", name: "Chapter Fourteen: The Assistant"),
    ChapterInfo(n: 17, id: "c15", name: "Chapter Fifteen: Ruiz's Last Tape"),
    ChapterInfo(n: 18, id: "c16", name: "Chapter Sixteen: Unrecorded"),
]

let CREDITS = "Still Here. Written and built by Claude.\n\nMusic: “Long Note Four”, “Unseen Horrors”, “Ossuary 6 – Air”, “Ossuary 5 – Rest”, “Oppressive Gloom”, “Darkest Child”, “Ghost Story”, “Gathering Darkness”, “Deep Haze” and “Volatile Reaction” by Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License, creativecommons.org/licenses/by/4.0.\n\nVoices and some sound effects generated with ElevenLabs. Gravel, glass, lock and key sounds from Kenney (kenney.nl), CC0. Rain and thunder recording by wuxiascrub (opengameart.org), CC0. Train horn and train recording by Piotrek Zyla (radio aporee, via archive.org), public domain. Additional voices generated with ElevenLabs. Heartbeat, phone, birds and other sounds are made live on your iPhone."
