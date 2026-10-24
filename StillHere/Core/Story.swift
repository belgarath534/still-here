import Foundation

// Converted from the web version by tools/js2swift.py, then fixed by hand.

var frontVisitor = "alvarez", bathVoice = "comeout";

var PHONE_TEXT = "“Listen to me. Don't let it know you're awake. It copies voices. Whatever it says, it isn't me. Get to the bathroom. Lock the door. Wait for the sun.”";

/* hold still */

/* chase */
var chaseRoundN = 0.0, roundSide = 0.0, roundLive = false;

func chaseRound() {
  clearScene();
  chaseRoundN += 1; roundLive = false;
  roundSide = Math.random() < 0.5 ? -1 : 1;
  heartbeat(130);
  show("Round " + str(chaseRoundN) + " of 3", "Listen.", [
    Choice("Dodge left", { dodge(-1) }),
    Choice("Dodge right", { dodge(1) }),
  ]);
  let cue = 1800.0 + Math.random() * 1500;
  after(cue, { 
    roundLive = true;
    let x = roundSide * 3.5;
    steps(5, [.from(x, 0, -7), .to(x * 0.6, 0, -1.5), .gap(0.32), .rate(1.3)]);
    play("breath", [.x(x * 0.7), .z(-3), .delay(0.6), .gain(1.3), .rate(0.85), .to(x * 0.5, 0, -1), .toSec(1.5)]);
   });
  let limit = opts.extraTime ? 16000 : hardOr(9000, 5500);
  after(cue + limit, { die("You froze.\n\nIt didn't.") });
}
func dodge(_ side: Double) {
  if (!roundLive) { say("Wait for the sound."); return; }
  if (side == roundSide) { return die("You dodged the wrong way. Straight into it."); }
  clearScene();
  whoosh(roundSide * 1.2);
  if (chaseRoundN < 3) {
    show("Close", "It rushes past you, so close you feel the air move.", [Choice("Next", { chaseRound() })]);
    after(3500, { chaseRound() });
  } else {
    heartbeat(100);
    show("Close", "It rushes past you and slams into the wall at the far end of the hall. Then nothing.\n\nYou keep moving. Hands on the wall. Feeling your way forward.", [
      Choice("Keep going", to("s7")),
    ]);
  }
}

func twist() {
  if (twistDone) { go("title"); return; }
  twistDone = true;
  clearScene();
  silenceAll();
  screen.dark = true;
  show("", "", []);
  after(4000, { play("stillhere", [.x(0.3), .z(0.15), .gain(1.8)]) });
  after(7600, scream);
  after(9800, { 
    screen.dark = false;
    markDone(1);
    show("Still here", "It was never outside the door.\n\nIt was in the bathroom with you. All night. Waiting for you to relax.\n\nThanks for playing Still Here.", [
      Choice("Play Chapter Two: The Motel", to("c2")),
      Choice("Main menu", to("title")),
    ]);
   });
}

/* ---------- chapter two ---------- */

var declined = false;
var JESS_TEXT = "“You got out. Good. My name's Jess. Listen — it's following you. It learned voices last night, and it's going to use them. I'm on my way. When I get to your door, I'll say: ‘It's Jess. Open up, we have to go.’ Don't open for anyone else.”";

var visits: [String] = [], visitN = 0.0, heldStill = false;

let VISIT_TEXT: Lookup<String> = ["real": "Two hard knocks. Then a woman, out of breath, almost shouting:\n\n“It's me! It's Jess! I'm parked right outside, the engine's running! Please, open the door, we have to go now!”\n\nBehind her, under the rain, a car engine is idling.", "jessfake": "One knock. Then a woman's voice, whispering:\n\n“It's Jess. Open up, we have to go.”\n\nExactly what she said on the phone. Word for word.", "alvarez": "A knock. Then a warm, worried voice:\n\n“Honey? It's Mrs. Alvarez, from next door. I heard screaming. Open the door, sweetheart. Let me in.”\n\nMrs. Alvarez lives two hundred miles from here.", "you": "A knock. Then a whisper, pressed right up against the door:\n\n“Let me in... it's cold out here... it's me. It's you.”"];
let VISIT_DEATH: Lookup<String> = ["jessfake": "You open the door.\n\nThere's no car. No Jess. Just rain.\n\nIt heard every word of your phone call. It was listening the whole time. It just repeated what it heard.", "alvarez": "You open the door.\n\nTwo hundred miles is nothing to it.", "you": "You open the door, and you're standing there in the rain. Wearing your face. Wearing it badly."];

/* ---------- chapter three ---------- */

var lockRound = 0.0, lockSide = 0.0, lockLive = false;
func lockNext() {
  clearScene();
  lockRound += 1; lockLive = false;
  lockSide = pick([-1.0, 1]);
  heartbeat(125);
  show("Something outside, " + str(lockRound) + " of 4", lockRound == 1
    ? "You lock every door. Then you hear footsteps on the gravel, circling the car.\n\nIt's looking for a way in. When it taps on a window, lock that side again, fast. Same side as the tap."
    : "Listen.", [
    Choice("Lock the left doors", { lockPress(-1) }),
    Choice("Lock the right doors", { lockPress(1) }),
  ]);
  let lead = lockRound == 1 ? 9000.0 : 1500;
  let a0 = Math.random() * Math.PI * 2;
  for i in upTo(5) {
    let a = a0 + i * 0.6;
    after(lead + i * 600, { play("gravel" + str((i % 3)), [.x(Math.cos(a) * 2.5), .z(Math.sin(a) * 2.5), .gain(0.9)]) });
  }
  let cue = lead + 3600 + Math.random() * 1200;
  after(cue, { 
    lockLive = true;
    play("tap0", [.x(lockSide * 1.1), .z(-0.2), .gain(1.6)]);
    play("tap1", [.x(lockSide * 1.1), .z(-0.2), .gain(1.6), .delay(0.35)]);
    play("tap0", [.x(lockSide * 1.1), .z(-0.2), .gain(1.6), .delay(0.7)]);
   });
  after(cue + (opts.extraTime ? 16000 : hardOr(9000, 5500)), {  offCar(); play("glassbang", [.x(lockSide), .z(-0.2), .gain(2)]); die("You froze.\n\nThe door handle lifted. The door opened.");  });
}
func lockPress(_ side: Double) {
  if (!lockLive) { say("Wait for the tap."); return; }
  if (side != lockSide) {
    offCar();
    return die("You locked the " + str((side < 0 ? "left" : "right")) + " side.\n\nThe tapping was on the " + str((lockSide < 0 ? "left" : "right")) + ". That door was already opening.");
  }
  clearScene();
  play("lock", [.x(lockSide * 1), .z(-0.3), .gain(1.6)]);
  if (lockRound < 4) {
    show("Locked", "Clunk. The handle rattles. Holds. The footsteps move on.", [Choice("Next", lockNext)]);
    after(3500, lockNext);
  } else {
    heartbeat(90);
    show("Locked", "Clunk. The handle rattles one last time. Then the footsteps stop.\n\nNothing. For a long time, nothing but the rain and the buzzing lights.", [
      Choice("Keep waiting", to("c3return")),
    ]);
  }
}

var realSide = 1.0;
func playReturn() -> Double {
  // the real Jess walks back from the shop with her keys; the copy is just suddenly there, and sounds like a phone
  let first = pick([-1.0, 1]);
  let seq = [first, -first];
  var t = 0.0;
  for side in seq  {
    if (side == realSide) {
      after(t, { shopChime(6) });
      after(t + 800, { gravel(7, [.from(6, 0, -7), .to(side * 1.5, 0, -0.5), .gap(0.5)]) });
      after(t + 1200, { play("keys", [.x(side * 2.5), .z(-3), .gain(1)]) });
      after(t + 4600, { play("keys", [.x(side * 1.3), .z(-0.4), .gain(1.2)]) });
      after(t + 5200, {  play("tap0", [.x(side * 1.1), .z(-0.2), .gain(1.5)]); play("tap1", [.x(side * 1.1), .z(-0.2), .gain(1.5), .delay(0.3)]);  });
      after(t + 6200, { play("jess_code", [.x(side * 1.2), .z(-0.3), .gain(1.4), .lowpass(5000)]) });
      t += 6200 + len("jess_code") + 1500;
    } else {
      after(t, {  play("tap0", [.x(side * 1.1), .z(-0.2), .gain(1.5)]); play("tap1", [.x(side * 1.1), .z(-0.2), .gain(1.5), .delay(0.3)]);  });
      after(t + 1000, { play("jess_code", [.x(side * 1.2), .z(-0.3), .gain(1.6), .phone(true)]) });
      t += 1000 + len("jess_code") + 1500;
    }
  }
  return t;
}
func returnChoices() -> [Choice] {
  return [
    Choice("Unlock the left door", { unlockSide(-1) }),
    Choice("Unlock the right door", { unlockSide(1) }),
    Choice("Listen again", {  clearScene(); listening(); let t = playReturn(); after(t, { show("Two voices", "Again: one knock on each side. One voice on each side, both saying the same thing.\n\n“It's Jess. Open up, we have to go.”", returnChoices()) });  }),
    Choice("Don't unlock either door", to("c3bad")),
  ];
}

func unlockSide(_ side: Double) {
  if (side != realSide) {
    offCar();
    return die("You unlock the " + str((side < 0 ? "left" : "right")) + " door. It slides into the car beside you, wearing Jess's voice.\n\nIt only knows what it's heard. And it heard her on the phone.");
  }
  go("c3drive");
}

/* ---------- chapter four ---------- */

let SNEAK = ["Unbuckle your seatbelt", "Open your door", "Step out of the car"];
var sneakStep = 0.0, strikes = 0.0, breathLive = false;

func sneakShow(_ text: String) {
  show("Move when it breathes", text, [Choice(SNEAK[sneakStep], sneakPress)]);
}
func breatheLoop(_ firstWait: Double? = nil) {
  after(firstWait ?? 3500 + Math.random() * 4000, { 
    breathLive = true;
    for i in upTo(2) { play("breath", [.x(0.1), .z(0.6), .delay(i * 1.25), .gain(1.4), .rate(0.9 + Math.random() * 0.1)]); }
    after(opts.extraTime ? 4500 : 2900, {  breathLive = false; breatheLoop();  });
   });
}
func sneakPress() {
  if (breathLive) {
    if (sneakStep == 0) { play("unlock", [.x(-0.2), .z(0.1), .gain(0.5)]); }
    else if (sneakStep == 1) { play("dooropen", [.x(-1), .z(-0.2), .gain(0.5), .rate(1.2)]); }
    else { gravel(2, [.from(-1.2, 0, 0), .to(-1.6, 0, 0.4), .gap(0.4), .gain(0.5)]); }
    sneakStep += 1;
    if (sneakStep == SNEAK.length) { return go("c4out"); }
    sneakShow(sneakStep == 1 ? "Click. The belt slides off your shoulder. The breathing doesn't change.\n\nNext: open your door. Wait for the breath." : "The door eases open. Cold morning air. The breathing doesn't change.\n\nLast: step out. Wait for the breath.");
    return;
  }
  strikes += 1;
  if (strikes >= hardOr(2, 1)) { return die("You moved in the silence. Again.\n\nThe back seat creaks. Something leans forward until its breath is on your neck."); }
  // first mistake: it stops, listens, and lets you live
  cancelTimers(); breathLive = false;
  heartbeat(140);
  show("It heard something", "The breathing stops.\n\nSilence. It's listening.\n\nDon't move.", []);
  after(9000, { 
    heartbeat(110);
    sneakShow("Slowly, it starts breathing again. It didn't find you.\n\nDon't do that again. Only move while it breathes.");
    breatheLoop(4000);
   });
}

var pleaIdx = 0.0;

/* ---------- interlude: the station ---------- */


var qIdx = 0.0;

var doorSeq: [String] = [], doorIdx = 0.0;

let DOOR_TEXT: Lookup<String> = ["fakeRuiz": "A knock. Then a voice, flat and close against the door:\n\n“It's Ruiz. Open the door.”\n\nWord for word what he said on the intercom. Even the crackle.", "fakeJess": "A softer knock. A woman's voice, whispering through the gap:\n\n“It's Jess. Open up, we have to go.”\n\nYou've heard her say exactly that before. Exactly that.", "real": "Fast, heavy footsteps. Keys jangling. A police radio hissing on someone's belt. Then pounding on the door:\n\n“Hey! Hey, it's Ruiz, it's me. Something is very wrong with this building. We're moving you. Right now. Stay right behind me.”"];
let DOOR_DEATH: Lookup<String> = ["fakeRuiz": "You open the door. The hallway is empty and black.\n\nSomewhere far off, the real Ruiz is shouting your name. Right next to your ear, something says it too.", "fakeJess": "You open the door for her.\n\nJess was in the lobby the whole time. She heard you scream."];

var junction = 0.0, ventSide = 0.0, ventLive = false;

func junctionNext() {
  clearScene();
  junction += 1; ventLive = false;
  ventSide = pick([-1.0, 1]);
  show("Corner " + str(junction) + " of 3", "Listen.", [
    Choice("Go left", { junctionPick(-1) }),
    Choice("Go right", { junctionPick(1) }),
  ]);
  conc(4, [.from(0.4, 0, 0), .to(0.4, 0, 0), .gap(0.5), .gain(0.7)]);
  if (junction == 1) { after(2200, { play("i_r11", [.x(0.4), .z(-0.4), .gain(1.3)]) }); }
  let cue = junction == 1 ? 2200 + len("i_r11") + 800 : 2500;
  after(cue, {  ventLive = true; crawl(ventSide * 2, 3500);  });
}
func junctionPick(_ side: Double) {
  if (!ventLive) { say("Wait. Listen for the vents first."); return; }
  if (side == ventSide) { return die("You went toward the sound.\n\nThe ceiling tile above you lifts."); }
  ventLive = false; clearScene(); listening();
  conc(6, [.from(0, 0, 0), .to(side * 3, 0, -3), .gap(0.3), .gain(0.8)]);
  if (junction == 1) { go("icell"); }
  else if (junction == 2) { go("icall"); }
  else { go("iradio"); }
}

/* ---------- chapter five ---------- */

var secretWord = "river";
var c5asked = false, c5wait = false, c5letring = false;

var c5visits: [String] = [], c5idx = 0.0;
let C5_TEXT: Lookup<String> = ["fakeJess": "A knock. Then Jess's voice, clear and close through the door. Not crackly. Not wrong. Exactly her:\n\n“It's me. Open the door. I love you.”\n\nBehind the cabin, the generator is still silent.", "fakeYou": "A knock. Then a whisper, pressed against the door:\n\n“Let me in... it's cold out here... it's me. It's you.”", "real": "Behind the cabin, the generator coughs and roars back to life. Running footsteps splash through the mud. Pounding on the door:\n\n“Hey! It's me! The generator's running, let me in, I'm freezing!”"];
let C5_DEATH: Lookup<String> = ["fakeJess": "You open the door. Jess is standing in the rain, smiling at you.\n\nThen, behind the cabin, the generator coughs back to life. And far away, you hear Jess calling your name.", "fakeYou": "You open the door, and you're standing there in the rain. You smile at yourself. Only one of you means it."];

func c5doorChoices(_ v: String, _ text: String, _ asked: Bool = false) {
  var opts2 = [
    Choice("Open the door", { v == "real" ? go("c5shed") : die(C5_DEATH[v]) }),
  ];
  if (!asked) { opts2.push(Choice("Ask through the door: “What did you write on my hand?”", { try await c5ask(v) })); }
  opts2.push(Choice("Stay quiet", { 
    if (v == "real") { return go("c5bad"); }
    clearScene(); listening();
    play("scratch", [.z(-2), .gain(1.2), .rate(0.8)]); play("scratch", [.z(-2), .gain(1.2), .rate(0.7), .delay(1.2)]);
    after(5500, {  c5idx += 1; go("c5door");  });
   }));
  show("Someone at the door", text, opts2);
}
@MainActor func c5ask(_ v: String) async throws {
  clearScene(); listening();
  try await wait(1500);
  var line = "", text = "";
  if (v == "real") { line = "c5_" + str(secretWord); text = "“It was ‘" + str(secretWord) + "’! You dork. Now let me in!”"; }
  else if (v == "fakeJess") { line = "c5_deflect"; text = "A pause. Then, sweetly: “Please. Just open the door. I love you.”\n\nIt didn't answer the question."; }
  else { line = "heart"; text = "Silence. Then a soft laugh, and a whisper: “I can hear your heart.”"; }
  play(line, [.z(-2), .gain(1.4), .lowpass(5000)]);
  try await wait(len(line) + 800);
  c5doorChoices(v, text, true);
}

/* ---------- act two and three helpers ---------- */

// "hold still" scene: one or more tempting buttons that kill you, scripted sounds, then it moves on

/* ---------- endings + tapes menus ---------- */

/* ---------- chapter six: the tapes ---------- */
var tapesHeard: [String] = [];

func c6menu(_ text: String) {
  let T = [
    ("girl", "Tape one: “Interview, the Price girl, October 1987”"),
    ("dj", "Tape two: “KROD broadcast, 2 a.m.”"),
    ("walter", "Tape three: “Walter Hask. Do not play.”"),
  ];
  var choices = T.map({ (id, label) in (Choice(label + (tapesHeard.includes(id) ? " (played)" : ""), { go("c6t_" + str(id)) })) });
  if (!tapesFound.includes("t4")) { choices.push(Choice("Look at the bottom of the box", { @MainActor in 
    clearScene(); listening();
    try await wait(1200);
    findTape("t4");
    try await tape("t4");
    c6menu("Taped under the bottom of the box, a tiny cassette with no label. A tired old voice: “If you're hearing this, you found my tapes. Don't play them out loud.”\n\nToo late.");
   })); }
  if (tapesHeard.length == 3) { choices.unshift(Choice("Turn off the tape player", to("c6after"))); }
  show("The tapes", text, choices);
}

/* ---------- chapter seven: the radio tower ---------- */

var dial = 50.0, targets: [Double] = [], foundStations: [Double] = [];

func tuneChoices() -> [Choice] {
  return [
    Choice("Turn the dial down", { tuneTo(dial - 5) }),
    Choice("Turn the dial up", { tuneTo(dial + 5) }),
    Choice("Check the dial", { say("The dial is at " + str(dial) + ". Found " + str(foundStations.length) + " of 3.") }),
  ];
}
func tuneTo(_ v: Double) {
  dial = Math.max(0, Math.min(100, v));
  var best = 999.0, bi = -1.0;
  targets.forEachI({ t, i in  if (!foundStations.includes(i)) { let d = Math.abs(t - dial); if (d < best) { best = d; bi = i; } }  });
  tone([.type("square"), .f(300 + dial * 6), .dur(0.03), .gain(0.05), .x(0.4), .z(-0.6)]);
  if (best == 0) {
    foundStations.push(bi);
    radio(0.01);
    clearScene();
    let st = STATIONS[foundStations.length - 1];
    play(st.clip, [.x(0.4), .z(-0.6), .phone(true), .gain(1.6)]);
    after(len(st.clip) + 600, { 
      radio(0.12);
      if (foundStations.length == 3) { radio(0); go("c7stairs"); return; }
      show("The radio", "Dial " + str(dial) + ". " + str(st.text) + "\n\nFound " + str(foundStations.length) + " of 3. Keep turning.", tuneChoices());
     });
    return;
  }
  radio(best <= 10 ? 0.05 : best <= 20 ? 0.08 : 0.12);
  if (best <= 10 && bi >= 0) { play(STATIONS[foundStations.length].clip, [.x(0.4), .z(-0.6), .phone(true), .gain(best <= 5 ? 0.5 : 0.25), .lowpass(1200)]); }
  say("Dial " + str(dial) + str((best <= 10 ? ". Something's there, close." : best <= 20 ? ". The static thins." : ".")));
}

let CLIMB = ["Climb the first flight", "Climb the second flight", "Climb to the booth"];
var climbStep = 0.0, gustLive = false, climbStrikes = 0.0;

func climbShow(_ text: String) { show("The stairs", text, [Choice(CLIMB[climbStep], climbPress)]); }
func gustLoop(_ first: Double? = nil) {
  after(first ?? 3500 + Math.random() * 4500, { 
    gustLive = true;
    wind(0.35); play("creak", [.y(4), .z(-2), .gain(1.4), .rate(0.6)]);
    after(opts.extraTime ? 4500 : hardOr(3000, 2000), {  gustLive = false; wind(0.04); gustLoop();  });
   });
}
func climbPress() {
  if (gustLive) {
    for i in upTo(3) { play("metalstep", [.y(i * 0.4), .z(-0.3), .delay(i * 0.35), .gain(0.5), .rate(0.9)]); }
    climbStep += 1;
    if (climbStep == CLIMB.length) { return go("c7booth"); }
    climbShow("The wind howls and the stairs groan under you. Nothing hears. Wait for the next gust.");
    return;
  }
  climbStrikes += 1;
  for i in upTo(2) { play("metalstep", [.z(-0.3), .delay(i * 0.3), .gain(1.4)]); }
  if (climbStrikes >= hardOr(2, 1)) { return die("The stairs ring like a bell in the silence.\n\nFrom every dead speaker in the station at once: “Caller, you're on the air.”"); }
  cancelTimers(); gustLive = false;
  heartbeat(140);
  play("c7_djloop", [.y(3), .z(-1), .gain(0.6), .rate(0.9), .lowpass(2500)]);
  show("It heard you", "Clang. The step rings out in the silence.\n\nFrom a speaker somewhere above, the DJ's voice, slow and wrong. Then nothing.\n\nDon't move.", []);
  after(10000, {  heartbeat(110); climbShow("It goes quiet again. Wait for the wind."); gustLoop(3000);  });
}

/* ---------- chapter eight: mrs. alvarez ---------- */

var landing = 0.0, stairSide = 0.0, stairLive = false;

func stairNext() {
  clearScene();
  landing += 1; stairLive = false; stairSide = pick([1.0, -1]); // 1 = it's above you, -1 = it's below
  show("Landing " + str(landing) + " of 3", "Listen.", [
    Choice("Keep going down", { stairPick(-1) }),
    Choice("Go through the door on this floor", { stairPick(1) }),
  ]);
  conc(4, [.from(0, -0.5, 0), .to(0, -1, -1), .gap(0.4), .gain(0.6)]);
  after(2400, { 
    stairLive = true;
    for i in upTo(5) { play(pick(["scratch", "knock", "metalstep"]), [.y(stairSide * 3), .z(-0.5), .delay(i * 0.5), .gain(1.3), .lowpass(stairSide > 0 ? 9000 : 700), .rate(0.8)]); }
   });
}
func stairPick(_ dir: Double) { // dir -1 = down, 1 = this floor (away from something below)
  if (!stairLive) { say("Listen first."); return; }
  // it's above: going down is safe. It's below: leave by this floor's door.
  if ((stairSide > 0 && dir != -1) || (stairSide < 0 && dir != 1)) { return die(stairSide > 0 ? "You stopped on the landing. It was right above you. It didn't need the stairs." : "You kept going down. Toward the muffled sound. It was waiting at the bottom."); }
  stairLive = false; clearScene(); listening();
  conc(5, [.from(0, 0, 0), .to(0, dir < 0 ? -2 : 0, -3), .gap(0.3), .gain(0.7)]);
  if (landing == 2) { return go("c8vent"); }
  if (landing == 3) { return go("c8end"); }
  after(2000, stairNext);
}

/* ---------- interlude two: ruiz ---------- */

/* ---------- chapter nine: separated ---------- */
var woodsStep = 0.0, woodsDir = 0.0, woodsLive = false, woodsStrikes = 0.0;

func woodsNext() {
  clearScene();
  woodsStep += 1; woodsLive = false;
  woodsDir = pick([-1.0, 0, 1]);
  let fake = pick([-1.0, 0, 1].filter({ d in d != woodsDir }));
  heartbeat(115);
  show("The woods, " + str(woodsStep) + " of 4", "Listen.", [
    Choice("Go left", { woodsPick(-1) }),
    Choice("Go ahead", { woodsPick(0) }),
    Choice("Go right", { woodsPick(1) }),
  ]);
  let clip = (woodsStep % 2 != 0) ? "c9_call1" : "c9_call2";
  let pos = { (d: Double) -> [Double] in [d * 6, 0, d == 0 ? -8 : -3] };
  let first = pick([true, false]);
  let real = {  let p = pos(woodsDir); gravel(6, [.from(p[0] - 1.5, 0, p[2]), .to(p[0] + 1.5, 0, p[2] + 1), .gap(0.4), .gain(1)]); play(clip, [.x(p[0]), .z(p[2]), .delay(0.4), .gain(1.4), .lowpass(5000)]);  };
  let copy = {  let p = pos(fake); play(clip, [.x(p[0]), .z(p[2]), .gain(1.4), .lowpass(5000)]);  };
  after(2000, {  woodsLive = true; (first ? real : copy)();  });
  after(2000 + len(clip) + 1500, { (first ? copy : real)() });
}
func woodsPick(_ d: Double) {
  if (!woodsLive) { say("Listen first."); return; }
  if (d != woodsDir) {
    woodsStrikes += 1;
    if (woodsStrikes >= hardOr(2, 1)) { return die("You run toward the voice. It's standing perfectly still in the dark, waiting, saying her words.\n\nIt doesn't need to move. You came to it."); }
    woodsLive = false; clearScene();
    for i in upTo(3) { play("breath", [.x(d * 2), .z(-1.5), .delay(i * 1.3), .gain(1.3)]); }
    show("Wrong way", "You stumble toward the voice and stop. No footsteps. Just breathing, very close, where the voice was.\n\nYou back away slowly. It doesn't follow. Not yet.\n\nOne more mistake and it will.", [Choice("Listen again", {  woodsStep -= 1; woodsNext();  })]);
    return;
  }
  woodsLive = false; clearScene(); listening();
  gravel(6, [.from(0, 0, 0), .to(d * 4, 0, -4), .gap(0.3), .gain(0.8)]);
  if (woodsStep < 4) { after(2500, woodsNext); }
  else { after(2500, { go("c9found") }); }
}

/* ---------- chapter ten: the hollow ---------- */
var noiseLvl = 0.0, room = 0.0;

func c10act(_ n: Double) {
  noiseLvl += n;
  var r = ROOMS[room];
  clearScene();
  if (n >= 2) { for i in upTo(n) { play(pick(["metalstep", "gravel0", "creak"]), [.z(-0.5), .delay(i * 0.3), .gain(0.7 + n * 0.1)]); } }
  else { play("gravel1", [.z(-0.5), .gain(0.3)]); }
  if (noiseLvl >= 8) { return die("Too loud. Somewhere far below you, every voice in the mountain stops talking at once.\n\nThen they all say your name."); }
  if (noiseLvl >= 5) { heartbeat(130); play("breath", [.z(-6), .gain(0.8), .lowpass(2000), .delay(1)]); say("Something deep in the mine stirs. Noise: " + str(noiseLvl) + " out of 8."); }
  room += 1;
  after(2500, { room < ROOMS.length ? go("c10room") : go("c10heart") });
}

/* ---------- chapter eleven: your voice ---------- */
var usedMic = false;
/// Records a few seconds from the microphone. The recording only ever lives in memory.
@MainActor func recordVoice(_ ms: Double) async throws {
  let pcm = try await audio.record(seconds: ms / 1000)
  audio.store("myvoice", pcm); audio.store("myvoice_rev", nil)
}
func useStandInVoice() { audio.store("myvoice", audio.pcm("me")); audio.store("myvoice_rev", nil) }
func ensureMyVoice() { if !has("myvoice") { useStandInVoice() } }

/* ---------- chapter twelve: still here ---------- */
var c12strikes = 0.0;

/* ---------- act four: playback ---------- */

/* chapter thirteen: after */

@MainActor func c13dance(_ kind: String) async throws {
  closeness += 1; clearScene(); listening();
  if (kind == "kitchen") { music("m_rest", 0.35, 2); for i in upTo(8) { play("conc" + str((i % 3)), [.x(Math.cos(i) * 0.6), .z(Math.sin(i) * 0.6), .delay(i * 0.7), .gain(0.4)]); } }
  else if (kind == "river") { city(0.02); rain(0.06, true); birds(true); }
  else { rain(0.25); thunderSoon(4000); }
  try await wait(7000);
  try await say2("a13_quiet", [.x(-0.3), .z(-0.15), .gain(1.2)], 1200);
  birds(false); rain(0); music("m_rest", 0.14, 3); city(0.05);
  show("Date night", str((kind == "kitchen" ? "No music speaker, just your phone on the counter. You're both terrible dancers. Jess doesn't care." : kind == "river" ? "The river is loud and alive and nothing like the silence in the mine. Jess holds your arm the whole way." : "Rain on the window, a blanket, her head on your shoulder. For once, rain is just rain.")) + "\n\nShe says, very softly: “You know what I love? It's so quiet here. Not scary quiet. Just... ours.”", [
    Choice("Continue", to("c13news")),
  ]);
}

/* chapter fourteen: the assistant */

var hunt = 0.0, huntStrikes = 0.0, huntRoom = 0.0, huntLive = false, huntLeft: [Double] = [];
func huntNext() {
  clearScene();
  if (hunt == 0) { huntLeft = shuffle([0.0, 1, 2, 3]); music("m_volatile", 0.15, 2); }
  hunt += 1; huntLive = false;
  huntRoom = huntLeft[hunt - 1];
  heartbeat(125);
  show("Speaker " + str(hunt) + " of 4", "Listen.", ROOMS4.mapI({ r, i in (Choice(r.label, { huntPick(i) })) }));
  let r = ROOMS4[huntRoom];
  let voice = pick(["hello", "jess_code", "c5_love", "i_r9", "c4_you", "c8_fakealv", "c5_glad"]);
  after(1800, {  huntLive = true; speakerChime(r.x, r.z); play(voice, [.x(r.x), .z(r.z), .phone(true), .gain(1.5), .delay(0.5)]);  });
  after(1800 + len(voice) + 3000, {  speakerChime(r.x, r.z); play(voice, [.x(r.x), .z(r.z), .phone(true), .gain(1.3), .delay(0.5), .rate(0.9)]);  });
  after(opts.extraTime ? 30000 : hardOr(18000, 10000), {  play("a14_crunlock", [.x(r.x), .z(r.z), .phone(true), .gain(1.5)]); after(2500, { die("Before you got to it, it finished its sentence, in her voice and yours: “Unlock the front door.”") });  });
}
func huntPick(_ i: Double) {
  if (!huntLive) { say("Listen for it first."); return; }
  let r = ROOMS4[huntRoom];
  if (i != huntRoom) {
    huntStrikes += 1;
    play("a14_glitch", [.x(r.x), .z(r.z), .phone(true), .gain(1.4)]);
    if (huntStrikes >= hardOr(3, 2)) { huntLive = false; after(len("a14_glitch") + 500, { die("You ran to the wrong room. Behind you, from the right one: “Okay. Unlocking the front door.”") }); return; }
    say("Wrong room. It's still talking.");
    return;
  }
  huntLive = false; clearScene(); listening();
  unplug(r.x, r.z);
  if (hunt < 4) { after(2500, huntNext); }
  else { after(3000, { go("c14door") }); }
}

/* chapter fifteen: ruiz's last tape */

var burnCount = 0.0;

func burnNext() {
  clearScene(); listening();
  let (clip, name) = BURN[burnCount]; burnCount += 1;
  fire(1);
  burnHiss();
  play(clip, [.x(0.3), .z(-1), .phone(true), .gain(1.3), .rate(1.15)]);
  after(1500, { play("scream", [.x(0.3), .z(-1), .gain(opts.soft ? 0.15 : 0.45), .rate(1.6), .lowpass(3000)]) });
  after(3500, { 
    fire(0.6);
    if (burnCount < BURN.length) { show("The barrel", str(name) + " goes into the fire. As the tape melts, the voice on it speeds up, and rises, and screams. Then it's gone.\n\nThere are more.", [Choice("Throw in the next one", burnNext)]); }
    else { go("c15danny"); }
   });
}

/* chapter sixteen: unrecorded */

var delIdx = 0.0;

func delNext() {
  clearScene();
  if (delIdx >= DELETE.length) { return go("c16last"); }
  let (_, label, _) = DELETE[delIdx];
  heartbeat(100 + delIdx * 8);
  show("Deleting", delIdx == 0 ? "The first one." : "Next.", [Choice(label, { try await delDo() })]);
}
@MainActor func delDo() async throws {
  let (clip, _, text) = DELETE[delIdx]; delIdx += 1;
  clearScene(); listening();
  play(clip, [.x(0.3), .z(-0.4), .phone(true), .gain(1.4)]);
  try await wait(Math.min(len(clip), 4500));
  stopAll(); tone([.f(500), .f2(80), .dur(0.4), .gain(0.15), .x(0.3), .z(-0.4)]);
  try await wait(1200);
  if (delIdx == 2) { try await say2("a16_beg", [.z(-2), .gain(1.4)], 600); }
  if (delIdx == 3) { try await say2("a16_forget", [.x(1.2), .z(-1), .gain(1.3)], 600); }
  show("Deleting", text + (delIdx == 2 ? "\n\nFrom every dead speaker at once: “Don't. Please. I'll be good. I'll only use one voice.”" : delIdx == 3 ? "\n\nThen Jess's voice, from across the room, where Jess isn't: “If you delete me, you'll forget how I sound.”" : ""), [Choice("Keep going", delNext)]);
}

func registerStory1() {
    scene("s1", true) { 
      music("m_drone", 0.3, 6);
      heartbeat(0);
      frontVisitor = pick(["alvarez", "you"]);
      bathVoice = pick(["comeout", "me"]);
      show("3:12 AM", "You wake up. You don't know why.\n\nThe house is silent. Too silent. The fridge isn't humming. The power is out.\n\nYour phone on the nightstand says 3:12 AM. Three percent battery.\n\nYou live alone.", [
        Choice("Listen", to("s1b")),
      ]);
     }
    scene("s1b") { @MainActor in 
      listening();
      try await wait(3500);
      play("knock", [.z(-3.5), .lowpass(3000)]);
      try await wait(2600);
      heartbeat(66);
      show("Knocking", "Three knocks. On your bedroom door.\n\nFrom inside the house.", [
        Choice("Call out: “Hello?”", to("s2hello")),
        Choice("Stay silent and listen", to("s2silent")),
        Choice("Pull the blanket over your head", to("s2blanket")),
      ]);
     }
    scene("s2hello") { @MainActor in 
      listening();
      try await wait(4500);
      play("hello", [.z(-3.5), .lowpass(2600), .gain(1.2)]);
      try await wait(4200);
      heartbeat(84);
      show("Your voice", "Silence. Then, from the other side of the door, your own voice answers.\n\n“Hello?”\n\nIt isn't quite right. It sounds like something that has only heard your voice once, and is still learning it.", [
        Choice("Continue", to("s3")),
      ]);
     }
    scene("s2silent") { @MainActor in 
      listening();
      try await wait(1500);
      steps(6, [.from(0, 0, -3.5), .to(5, 0, -6), .gap(0.9), .lowpass(2500)]);
      try await wait(9000);
      play("knock", [.x(-1.8), .z(-0.4), .gain(1.3)]);
      try await wait(2800);
      heartbeat(88);
      show("The closet", "Footsteps, walking away down the hall. Gone.\n\nThen a knock. From your closet.\n\nInside your room. To your left.", [
        Choice("Continue", to("s3")),
      ]);
     }
    scene("s2blanket") { @MainActor in 
      listening();
      try await wait(2500);
      for i in upTo(4) { play("breath", [.x(0.45), .z(0.05), .delay(i * 1.5), .gain(1.1), .rate(0.95 + Math.random() * 0.1)]); }
      try await wait(7000);
      heartbeat(92);
      show("Under the blanket", "Under the blanket your breath sounds so loud.\n\nThen you realise: not all of the breathing is yours.\n\nSomething is breathing on the other side of the blanket. Right next to your ear. Patient. Waiting.", [
        Choice("Continue", to("s3")),
      ]);
     }
    scene("s3") { @MainActor in 
      listening();
      try await wait(2000);
      buzz(3);
      try await wait(5200);
      show("Unknown caller", "Your phone buzzes against the nightstand, loud as a drill. Unknown caller. Two percent battery.", [
        Choice("Answer", to("s3answer")),
        Choice("Decline", to("s3decline")),
      ]);
      after(3000, { buzz(2) });
     }
    scene("s3answer") { @MainActor in 
      listening();
      try await wait(2200);
      play("phone", [.x(0.3), .z(-0.2), .phone(true), .gain(1.4)]);
      try await wait(12500);
      tone([.f(480), .dur(0.3), .gain(0.15), .x(0.3), .z(-0.2)]);
      try await wait(900);
      show("The call", "A woman, whispering, terrified:\n\n" + str(PHONE_TEXT) + "\n\nThe line goes dead.", [
        Choice("Continue", to("s4")),
      ]);
     }
    scene("s3decline") { @MainActor in 
      listening();
      try await wait(4000);
      buzz(1);
      try await wait(2500);
      play("phone", [.x(0.3), .z(-0.5), .phone(true), .gain(1.6)]);
      try await wait(12500);
      show("Voicemail", "You decline. Silence.\n\nThen, without you touching it, the phone plays a voicemail. On speaker. Loud.\n\n" + str(PHONE_TEXT) + "\n\nIf it didn't know you were awake before, it does now.", [
        Choice("Continue", to("s4")),
      ]);
     }
    scene("s4", true) { 
      music("m_drone", 0.3, 3);
      heartbeat(96);
      let dir = pick([-1.0, 1]), ear = pick([-1.0, 1]);
      show("Don't move", "Your bedroom door is opening.\n\nIt's in the room. Don't press anything. Don't move. Don't breathe. If you touch anything, it will hear you.\n\nWait until it leaves.", [
        Choice("Run for the door", { die("You ran. Bare feet slapping the floor. You made it two steps.\n\nIt was faster.") }),
        Choice("Scream for help", { die("You screamed for help.\n\nSomething answered. It was already standing over you.") }),
      ]);
      after(3000, { play("creak", [.z(-3.5), .gain(1.6)]) });
      // circle the bed
      let n = 18.0;
      for i in upTo(n) {
        let a = Math.PI * 1.5 + dir * (i / n) * Math.PI * 2.2, r = 2.2 - i * 0.07;
        after(6500 + i * 900, { play("steps", [.x(Math.cos(a) * r), .z(Math.sin(a) * r), .rate(0.9 + Math.random() * 0.1), .gain(0.9)]) });
      }
      after(10000, { heartbeat(120) });
      after(14000, {  for i in upTo(3) { play("breath", [.x(-dir * 0.9), .z(-0.3), .delay(i * 1.3), .gain(1), .to(dir * 0.9, 0, -0.3), .toSec(4)]); }  });
      after(23500, { play("heart", [.x(ear * 0.35), .z(0.1), .gain(1.5)]) });
      after(29000, { steps(6, [.from(1, 0, 1.5), .to(4, 0, 6), .gap(0.9)]) });
      after(36000, {  heartbeat(80); go("s5");  });
     }
    scene("s5") { 
      show("It left", "The footsteps fade down the hall, toward the kitchen.\n\nIt's gone. For now.\n\nThe bathroom is at the end of the hall, past the front door. You slide out of bed. The floor is cold.", [
        Choice("Step into the hallway", to("s6")),
      ]);
      after(7000, { play("knock", [.x(6), .z(-8), .gain(0.5), .lowpass(1500)]) });
     }
    scene("s6", true) { 
      chaseRoundN = 0;
      music("m_chase", 0.28, 4);
      show("The hallway", "The hallway is pitch black.\n\nSomething is coming back. Fast.\n\nListen for which side it comes from, then dodge the other way. If it comes from the left, dodge right. If it comes from the right, dodge left.\n\nThree times. Don't freeze.", [
        Choice("I'm ready", { chaseRound() }),
      ]);
     }
    scene("s7", true) { @MainActor in 
      music("m_drone", 0.25, 4);
      listening();
      try await wait(1500);
      play("knock", [.z(-2.5), .gain(1.2)]);
      try await wait(2200);
      let you = frontVisitor == "you";
      play(you ? "me" : "neighbor", [.z(-2.5), .lowpass(3500), .gain(you ? 1.4 : 1.2)]);
      try await wait(len(you ? "me" : "neighbor") + 700);
      show("The front door", you
        ? "You reach the front door. Someone on the other side is knocking.\n\nThen a whisper, pressed against the wood:\n\n“Let me in... it's cold out here... it's me. It's you.”\n\nIt's your voice. Almost. The bathroom is a few steps further."
        : "You reach the front door. Someone on the other side is knocking.\n\n“Honey? It's Mrs. Alvarez, from next door. I heard screaming. Open the door, sweetheart. Let me in.”\n\nShe sounds so real. The bathroom is a few steps further.", [
        Choice("Open the front door", { die("You open the door. Cold air. An empty porch. Nobody there.\n\nThe voice was never outside. It was behind you.") }),
        Choice("Keep going to the bathroom", to("s8")),
        Choice("Whisper: “Who's there?”", to("s7b")),
      ]);
     }
}

func registerStory2() {
    scene("s7b") { @MainActor in 
      listening();
      try await wait(4000);
      play("hello", [.z(-2.5), .lowpass(2400), .rate(0.78), .gain(1.3)]);
      try await wait(4500);
      show("The front door", "The knocking stops. Mid-knock.\n\nThen, through the door, in a voice far too deep:\n\n“Hello?”", [
        Choice("Open the front door", { die("You open the door anyway.\n\nIt's been learning your voice all night. It got very, very good at it.") }),
        Choice("Run to the bathroom", to("s8")),
      ]);
     }
    scene("s8", true) { 
      music("m_air", 0.3, 5);
      heartbeat(90);
      show("The bathroom", "You lock the bathroom door behind you and slide down against it. The tiles are cold through your clothes.\n\nThe woman on the phone said: wait for the sun. Sunrise is at 6:40.\n\nYour phone dies with a little chime. Now you don't know what time it is.", [
        Choice("Wait", to("s9")),
      ]);
      after(5500, chime);
     }
    scene("s9") { 
      show("Wait for the sun", "Something has stopped outside the bathroom door.\n\nWhatever you hear, don't open it. Don't press anything. Just wait for the sun.", [
        Choice("Open the door", { die(bathVoice == "me"
          ? "You open the door.\n\nYou're standing there. The other you. Smiling.\n\nThe smile keeps going. Long after a mouth should stop."
          : "You open the door.\n\nShe's there. Mrs. Alvarez. Smiling.\n\nHer smile keeps going. Long after a mouth should stop.") }),
      ]);
      after(3500, { steps(4, [.from(0, 0, -4), .to(0, 0, -1.2), .gap(0.9)]) });
      after(8000, {  heartbeat(115); for i in upTo(3) { play("scratch", [.z(-0.8), .delay(i * 1.1), .gain(1.2), .rate(0.8 + Math.random() * 0.3)]); }  });
      after(13000, { play(bathVoice, [.z(-1), .lowpass(2800), .gain(1.3)]) });
      after(21500, { play(bathVoice, [.z(-0.8), .lowpass(2200), .gain(1.6), .rate(0.7)]) });
      after(30500, {  play("knock", [.z(-0.6), .gain(1.8)]); play("knock", [.z(-0.6), .gain(1.8), .delay(1.9), .rate(0.9)]);  });
      after(36000, { play("heart", [.z(-0.7), .lowpass(2500), .gain(1.4)]) });
      after(42000, {  heartbeat(70); music("m_air", 0.12, 8);  });
      after(50000, { heartStop() });
      after(56000, {  birds(true); music("m_rest", 0.3, 6);  });
      after(62000, { go("s10") });
     }
    scene("s10") { 
      birds(true);
      show("Dawn", "Birds.\n\nGrey light under the door. Somewhere outside, a car starts. A dog barks. Normal sounds. Morning sounds.\n\nThe house is quiet.\n\nYou made it. You survived the night.", [
        Choice("Open the bathroom door", to("ending")),
      ]);
     }
    scene("ending") { 
      birds(true);
      show("You survived", "Sunlight floods the hallway. The front door is shut and locked. Nothing is there.\n\nThank you for playing.\n\n" + str(CREDITS), [
        Choice("Play again", twist),
        Choice("Main menu", twist),
      ]);
      after(40000, twist);
     }
    scene("c2", true) { 
      music("m_drone", 0.22, 5); rain(0.12); heartbeat(0);
      show("Chapter Two: The Motel", "You didn't go home. You drove until the sun came up, and then you kept driving.\n\nNow it's 11 PM, and you're in Room 12 of the Pine Rest Motel, two hundred miles from your house. Rain hammers the roof. You haven't slept in forty hours.\n\nYou tell yourself it's over. It stayed in the house. It has to have stayed in the house.", [
        Choice("Lie down", to("c2b")),
      ]);
     }
    scene("c2b") { @MainActor in 
      rain(0.12);
      listening();
      try await wait(5000);
      buzz(3);
      try await wait(5200);
      show("Unknown caller", "Your phone buzzes on the nightstand. Unknown caller. The same number as last night.", [
        Choice("Answer", {  declined = false; go("c2call");  }),
        Choice("Decline", {  declined = true; go("c2call");  }),
      ]);
      after(3000, { buzz(2) });
     }
    scene("c2call") { @MainActor in 
      listening();
      if (declined) { try await wait(3500); buzz(1); try await wait(2500); }
      else { try await wait(2000); }
      play("jess_call", [.x(0.3), .z(declined ? -0.5 : -0.2), .phone(true), .gain(declined ? 1.6 : 1.4)]);
      try await wait(len("jess_call") + 900);
      show("The call", str((declined
        ? "You decline. The phone answers itself anyway, on speaker. The same woman from last night:\n\n"
        : "The same woman from last night, whispering:\n\n")) + str(JESS_TEXT) + "\n\nThe line goes dead.", [
        Choice("Continue", to("c2wait")),
      ]);
     }
    scene("c2wait", true) { 
      let fakes = shuffle(["jessfake", "alvarez", "you"]);
      let realAt = 1.0 + Math.floor(Math.random() * 2); // at least one fake always comes first
      visits = fakes.slice(0, realAt).concat(["real"]);
      visitN = 0; heldStill = false;
      music("m_air", 0.2, 5); rain(0.14); heartbeat(0);
      show("Waiting", "You sit on the end of the bed, facing the door. The chain is on. The lock is turned.\n\nEvery car that passes on the highway sounds like it's slowing down.\n\nRemember what she told you. Listen carefully to whoever knocks.", [
        Choice("Wait", to("c2visit")),
      ]);
     }
    scene("c2visit") { @MainActor in 
      let v = visits[visitN];
      rain(0.14); heartbeat(0);
      listening();
      try await wait(3500 + Math.random() * 4000);
      if (v == "real") {
        engine(0.22);
        play("knock", [.z(-2.2), .gain(1.5)]); play("knock", [.z(-2.2), .gain(1.5), .delay(1.2), .rate(1.1)]);
        try await wait(2600);
        play("jess_real", [.z(-2.2), .lowpass(5000), .gain(1.2)]);
        try await wait(len("jess_real") + 800);
      } else {
        play("knock", [.z(-2.2), .gain(1.2)]);
        try await wait(2600);
        if (v == "jessfake") { play("jess_code", [.z(-2.2), .phone(true), .gain(1.6)]); }
        else if (v == "alvarez") { play("neighbor", [.z(-2.2), .lowpass(3500), .gain(1.2)]); }
        else { play("me", [.z(-2.2), .lowpass(3000), .gain(1.4)]); }
        try await wait(len(v == "jessfake" ? "jess_code" : v == "alvarez" ? "neighbor" : "me") + 1200);
      }
      heartbeat(104);
      show("Someone's at the door", VISIT_TEXT[v], [
        Choice("Open the door", { v == "real" ? go("c2car") : die(VISIT_DEATH[v]) }),
        Choice("Stay quiet", { v == "real" ? go("c2bad") : go("c2quiet") }),
      ]);
     }
    scene("c2quiet") { 
      let v = visits[visitN];
      let next = {  visitN += 1; go("c2visit");  };
      if (!heldStill) {
        heldStill = true;
        heartbeat(118);
        show("It's still there", "It doesn't leave.\n\nYou can hear it breathing against the door. It knows someone is in here. It's listening for you.\n\nDon't press anything. Don't make a sound.", [
          Choice("Open the door", { die(VISIT_DEATH[v]) }),
        ]);
        after(4000, {  for i in upTo(4) { play("breath", [.z(-0.9), .delay(i * 1.4), .gain(1.2), .rate(0.85)]); }  });
        after(11000, {  for i in upTo(3) { play("scratch", [.z(-0.8), .delay(i * 1.1), .gain(1.3), .rate(0.8 + Math.random() * 0.3)]); }  });
        after(16000, { play("heart", [.z(-0.8), .lowpass(2600), .gain(1.4)]) });
        after(22000, { steps(5, [.from(0, 0, -1.5), .to(5, 0, -6), .gap(0.8), .lowpass(2500)]) });
        after(28000, next);
      } else {
        show("Silence", "You don't move. You don't breathe.\n\nAfter a long time, footsteps walk away along the balcony.", [
          Choice("Keep waiting", next),
        ]);
        after(1500, { steps(5, [.from(0, 0, -1.5), .to(-5, 0, -6), .gap(0.8), .lowpass(2500)]) });
      }
     }
    scene("c2bad") { @MainActor in 
      listening();
      try await wait(5000);
      play("knock", [.z(-2.2), .gain(0.8)]);
      try await wait(6000);
      play("jess_scream", [.x(2.5), .z(-6), .gain(1.4), .lowpass(5000)]);
      after(1800, { engine(0) });
      try await wait(9000);
      heartStop(); musicCut();
      markEnding("alone");
      show("Ending: Alone", "You stayed quiet. You were so careful.\n\nThe engine stops. Then the screaming stops too.\n\nIn the morning, Jess's car is still in the parking lot, the driver's door hanging open, rain on the seats.\n\nShe said who she was. Just not word for word. She was out of breath. She was real.", [
        Choice("Try again from the last checkpoint", { go(checkpoint) }),
        Choice("Main menu", to("title")),
      ]);
     }
}

func registerStory3() {
    scene("c2car", true) { @MainActor in 
      engine(0.22);
      listening();
      try await wait(800);
      play("creak", [.z(-1.5), .gain(1.6), .rate(1.4)]);
      rain(0.4, true);
      try await wait(1500);
      steps(5, [.from(0, 0, -1), .to(1, 0, -3), .gap(0.3), .rate(1.4)]);
      try await wait(2200);
      carDoor(0.8);
      try await wait(700);
      carDoor(-0.8);
      rain(0.16); engine(0.4); music("m_drone", 0.15, 4); heartbeat(90);
      try await wait(3500);
      play("jess_car", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("jess_car") + 700);
      show("The car", "You throw the door open and run. Rain in your face. A hand grabs yours — warm, real — and pulls you into the passenger seat. Jess floors it. The motel disappears behind you.\n\nShe's shaking. So are you.\n\n“Okay. Okay. We're out. We're safe now... You can close your eyes.”", [
        Choice("Close your eyes", to("c2end")),
      ]);
     }
    scene("c2end") { 
      heartbeat(60);
      music("m_drone", 0.08, 6);
      show("", "You close your eyes.", []);
      after(9000, { play("thanks", [.x(0.3), .z(0.45), .gain(1.9)]) });
      after(9000 + len("thanks") + 400, {  heartStop(); scream(); skid();  });
      after(9000 + len("thanks") + 2200, { engine(0) });
      after(9000 + len("thanks") + 3600, { play("j_hear", [.x(-0.6), .z(-0.3), .gain(1.4)]) });
      after(9000 + len("thanks") + 4000 + len("j_hear"), { 
        silenceAll(); rain(0.2, true);
        markDone(2);
        show("End of Chapter Two", "Jess slams on the brakes. The car skids sideways across the wet road and stops.\n\nShe twists around. The back seat is empty.\n\n“Did you... did you hear that?” she whispers.\n\nYou did. You opened the door. You let her in.\n\nAnd you let something else in with her.", [
          Choice("Play Chapter Three: The Road", to("c3")),
          Choice("Main menu", to("title")),
          Choice("Credits", to("credits")),
        ]);
       });
     }
    scene("c3", true) { 
      music("m_drone", 0.18, 5); rain(0.18); engine(0.35); wipers(true); heartbeat(0); hum(0); radio(0);
      thunderSoon(6000);
      show("Chapter Three: The Road", "Jess doesn't stop the car. She doesn't say a word for ten miles. The wipers thump back and forth. Thunder rolls somewhere over the hills.\n\nThen, very quietly, she speaks.", [
        Choice("Listen", to("c3radio")),
      ]);
     }
    scene("c3radio") { @MainActor in 
      listening();
      try await wait(1200);
      play("j_incar", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("j_incar") + 2500);
      play("unlock", [.x(0.5), .z(-0.8)]);
      radio(0.05);
      try await wait(1200);
      play("news", [.x(0.5), .z(-0.8), .phone(true), .gain(1.5)]);
      try await wait(len("news") - 2500);
      radio(0.12);
      try await wait(3500);
      radio(0.06);
      play("hello", [.x(0.5), .z(-0.8), .phone(true), .gain(1.4)]);
      try await wait(len("hello") + 1500);
      radio(0.1);
      play("awake", [.x(0.5), .z(-0.8), .phone(true), .gain(1.5)]);
      try await wait(len("awake") + 1000);
      show("The radio", "“It's in the car with us,” Jess whispers. “Isn't it.”\n\nThen the radio turns itself on. A late-night news anchor:\n\n“Police are searching for two people last seen at the Pine Rest Motel off Route Nine, where guests reported screaming shortly after midnight. Officials are asking anyone who sees them not to stop. Not to help. And whatever you hear... do not open the door.”\n\nStatic. Then a different voice, through the same speakers:\n\n“Hello?”\n\n“I know you're awake.”", [
        Choice("Turn the radio off", to("c3off")),
        Choice("Turn it up", to("c3up")),
      ]);
     }
    scene("c3off") { @MainActor in 
      listening();
      play("unlock", [.x(0.5), .z(-0.8)]); radio(0);
      try await wait(3500);
      heartbeat(95);
      for i in upTo(3) { play("breath", [.x(0.15), .z(0.6), .delay(i * 1.4), .gain(1.2)]); }
      play("seat", [.z(0.9), .delay(4.2), .gain(1.3)]);
      try await wait(6000);
      show("The back seat", "Click. The radio goes dead.\n\nIn the silence, you both hear it. Breathing. Slow and wet. Right behind your seat.\n\nThen the back seat creaks, like something just shifted its weight.", [
        Choice("Continue", to("c3trunk")),
      ]);
     }
    scene("c3up") { @MainActor in 
      listening();
      radio(0.28);
      try await wait(2000);
      play("heart", [.x(0.5), .z(-0.8), .phone(true), .gain(1.8)]);
      try await wait(len("heart") + 500);
      radio(0);
      heartbeat(95);
      try await wait(1500);
      show("The radio", "You turn it up. The static roars. And under it, a whisper:\n\n“I can hear your heart.”\n\nThen it laughs. And the radio dies. Jess swears under her breath.", [
        Choice("Continue", to("c3trunk")),
      ]);
     }
    scene("c3trunk") { @MainActor in 
      listening();
      try await wait(2500);
      for i in upTo(3) { play("trunk", [.z(2.5), .delay(i * 0.9), .gain(1.6), .lowpass(2500), .rate(0.7)]); }
      try await wait(4500);
      play("j_gas", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("j_gas") + 600);
      show("The trunk", "Bang. Bang. Bang.\n\nSomething is hitting the trunk lid. From the inside.\n\nJess grips the wheel so hard her knuckles crack. “Okay. Okay. There's a gas station two miles up. Lights. People. We stop there.”", [
        Choice("Agree", to("c3gas")),
        Choice("Climb into the back seat to look", {  offCar(); die("You twist around and reach into the back seat, feeling for it in the dark.\n\nSomething reaches back.");  }),
      ]);
     }
    scene("c3gas", true) { @MainActor in 
      music("m_drone", 0.15, 3); rain(0.18); engine(0.35); wipers(true); heartbeat(0);
      listening();
      try await wait(1500);
      gravel(6, [.from(0, 0, -0.5), .to(0, 0, -0.5), .gap(0.25), .gain(0.6)]);
      engine(0.12);
      try await wait(2000);
      engine(0); wipers(false); hum(0.05);
      try await wait(1500);
      play("j_lock", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("j_lock") + 800);
      play("keys", [.x(-0.6), .z(-0.4), .gain(1.2)]);
      try await wait(1000);
      carDoor(-0.9);
      play("keys", [.x(-1.5), .z(-0.5), .delay(0.6)]);
      gravel(8, [.from(-1.5, 0, -0.5), .to(6, 0, -7), .gap(0.55)]);
      play("keys", [.x(2), .z(-3), .delay(2.5), .gain(0.8)]);
      after(5000, { shopChime(6) });
      try await wait(6500);
      show("Gas-N-Go", "The Gas-N-Go is open all night. Its lights buzz. Jess kills the engine.\n\n“Lock the doors behind me. I'm getting flares and a flashlight. When I come back, I'll knock and say it's me.”\n\nShe takes the keys. You hear them jingling in her hand as her shoes crunch away across the gravel, off to your right, toward the shop. The door chimes. She's inside.\n\nYou're alone in the car. You hope.", [
        Choice("Lock the doors and wait", {  lockRound = 0; lockNext();  }),
      ]);
     }
    scene("c3return") { 
      realSide = pick([-1.0, 1]);
      heartbeat(110);
      listening();
      let t = playReturn();
      after(t, { show("Two voices", "A knock on the window to your left. A knock on the window to your right.\n\nTwo voices. Both of them Jess. Both saying exactly the same thing:\n\n“It's Jess. Open up, we have to go.”\n\nOne of them walked back from the shop. One of them was already here.", returnChoices()) });
     }
    scene("c3bad") { @MainActor in 
      listening();
      try await wait(2500);
      play("tap0", [.x(realSide * 1.1), .z(-0.2), .gain(1.8)]); play("tap1", [.x(realSide * 1.1), .z(-0.2), .gain(1.8), .delay(0.25)]);
      try await wait(4500);
      play("jess_scream", [.x(realSide * 2), .z(-1), .gain(1.4)]);
      play("keys", [.x(realSide * 1.5), .z(-0.3), .delay(1.2), .gain(1.3), .rate(0.8)]);
      try await wait(7000);
      silenceAll(); offCar();
      markEnding("lockedin");
      show("Ending: Locked In", "You didn't unlock either door. You were so careful.\n\nThe scream stops. Something small hits the gravel. Her keys.\n\nYou're safe in the car. Locked in. No keys. And something is tapping, patiently, on the window. It has all night.", [
        Choice("Try again from the last checkpoint", { go(checkpoint) }),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c3drive") { @MainActor in 
      hum(0.05);
      listening();
      play("unlock", [.x(realSide), .z(-0.3), .gain(1.5)]);
      try await wait(600);
      carDoor(realSide * 0.9);
      play("keys", [.x(realSide * 0.6), .z(-0.4), .delay(0.5), .gain(1.2)]);
      try await wait(2000);
      play("j_heard", [.x(-0.6), .z(-0.3), .gain(1.3)]);
      try await wait(len("j_heard") + 500);
      engine(0.35); hum(0); wipers(true); heartbeat(100);
      gravel(6, [.from(0, 0, -0.5), .to(0, 0, -0.5), .gap(0.2), .gain(0.7)]);
      try await wait(2500);
      show("Go", "Jess drops in, soaked, keys shaking in her hand. “Did you hear it? It was right there. It had my voice.”\n\nShe starts the car. Gravel spits under the tires. You're moving.\n\nThe trunk is quiet now. The back seat is quiet. Up ahead, the sky is getting light.", [
        Choice("Keep driving", to("c3dawn")),
      ]);
     }
    scene("c3dawn") { @MainActor in 
      engine(0.3); wipers(false); rain(0.03); heartbeat(0);
      music("m_rest", 0.28, 6);
      after(3000, { birds(true) });
      listening();
      try await wait(6000);
      play("j_made", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("j_made") + 800);
      show("Sunrise", "The rain stops. The sun comes up, pale and orange.\n\nJess laughs, a shaky, exhausted laugh. “We made it. We actually made it.”\n\nTwo hundred miles. Three hundred. Nothing has made a sound for an hour.\n\nIt's over. It has to be over this time.", [
        Choice("Rest your head against the window", to("c3end")),
      ]);
     }
}

func registerStory4() {
    scene("c3end") { 
      engine(0.3);
      music("m_rest", 0.1, 6);
      show("", "You close your eyes.", []);
      after(9000, { play("jess_car", [.x(0.15), .z(0.55), .gain(1.7), .phone(true)]) });
      after(9000 + len("jess_car") + 300, {  scream(); skid();  });
      after(9000 + len("jess_car") + 2000, { engine(0) });
      after(9000 + len("jess_car") + 3600, { play("j_hear", [.x(-0.6), .z(-0.3), .gain(1.4)]) });
      after(9000 + len("jess_car") + 4000 + len("j_hear"), { 
        silenceAll(); offCar();
        markDone(3);
        show("End of Chapter Three", "Jess didn't say that.\n\nJess is right next to you, both hands on the wheel, staring at you. She heard it too.\n\nIt came from the back seat. In her voice. Word for word, the way she said it last night.\n\nIt never left the car. It's still here.", [
          Choice("Play Chapter Four: The Crossing", to("c4")),
          Choice("Main menu", to("title")),
          Choice("Credits", to("credits")),
        ]);
       });
     }
    scene("c4", true) { 
      music("m_drone", 0.16, 5); rain(0); engine(0.18); heartbeat(0); offCh4(); birds(false);
      show("Chapter Four: The Crossing", "Morning. Grey light. Jess turns off the highway onto a narrow country road and stops the car. The engine ticks over.\n\nNeither of you says anything for a long time.\n\nThen, without turning her head, Jess starts to whisper.", [
        Choice("Listen", to("c4plan")),
      ]);
     }
    scene("c4plan") { @MainActor in 
      engine(0.18);
      listening();
      try await wait(1500);
      play("c4_still", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("c4_still") + 800);
      for i in upTo(2) { play("breath", [.x(0.1), .z(0.6), .delay(i * 1.3), .gain(1.2)]); }
      try await wait(3500);
      play("c4_plan", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("c4_plan") + 600);
      engine(0);
      bells(0.5);
      try await wait(1500);
      show("The plan", "“It's still in here,” Jess whispers. “It's been in here the whole time. Don't turn around. Listen to me. Every single time, it needed someone to open the door for it. It can't open a locked one.”\n\nBehind you, it breathes.\n\n“I stopped on the tracks on purpose. The freight train comes through at seven fifteen. We get out, quietly, and we lock it in. It hunts by sound. So only move when it breathes.”\n\nJess turns off the engine. Somewhere down the line, the crossing bells start to ring.", [
        Choice("I'm ready", to("c4sneak")),
      ]);
     }
    scene("c4sneak", true) { 
      sneakStep = 0; strikes = 0; breathLive = false;
      bells(0.5); heartbeat(100);
      sneakShow("Behind you, it's breathing. Slow, wet breaths, with long silences in between.\n\nOnly move while it's breathing. The sound covers you. If you move in the silence, it will hear you.\n\nThree things: unbuckle your seatbelt, open your door, step out.");
      breatheLoop(10000);
     }
    scene("c4out") { @MainActor in 
      bells(0.6); heartbeat(120);
      listening();
      gravel(4, [.from(-1.6, 0, 0.4), .to(-2, 0, 3), .gap(0.45), .gain(0.7)]);
      gravel(4, [.from(1.6, 0, 0.4), .to(-1, 0, 3), .gap(0.45), .gain(0.5)]);
      try await wait(2600);
      play("keys", [.x(-0.8), .z(0), .gain(1)]);
      try await wait(900);
      fob();
      for i in upTo(4) { play("lock", [.x((i % 2 != 0) ? 1.5 : -1.5), .z(-2.5 - (i > 1 ? 1.5 : 0)), .delay(0.25 + i * 0.05), .gain(1.4)]); }
      try await wait(2600);
      pound(-3, 1.4);
      try await wait(3500);
      play("c4_walk", [.x(-0.6), .z(0), .gain(1.3)]);
      try await wait(len("c4_walk") + 600);
      show("Locked in", "You slip out of the car. Gravel under your shoes. Jess comes around the back of the car and presses the key fob.\n\nChirp. All four locks drop at once.\n\nFor one second, nothing. Then the car erupts. Something slams against the windows from the inside, again and again, rocking the car on its wheels.\n\nJess grabs your hand. “Okay. It's locked. Now we walk away. Whatever it says, don't stop. And don't go back.”", [
        Choice("Walk away", {  pleaIdx = 0; go("c4plea");  }),
      ]);
     }
    scene("c4plea") { @MainActor in 
      let p = PLEAS[pleaIdx];
      bells(0.6 + pleaIdx * 0.25); heartbeat(115 + pleaIdx * 8);
      pound(p.z, 1.4);
      listening();
      gravel(5, [.from(-0.4, 0, 0), .to(-0.4, 0, 0), .gap(0.5), .gain(0.6)]);
      try await wait(3200);
      play(p.clip, [.x(0), .z(p.z), .lowpass(3200), .gain(1.8)] + p.opt);
      try await wait(len(p.clip) + 700);
      if (pleaIdx == 2) { play("trainhorn", [.x(-25), .z(-10), .gain(0.8)]); }
      show("Don't stop", p.text, [
        Choice("Keep walking", {  pleaIdx += 1; go(pleaIdx < PLEAS.length ? "c4plea" : "c4train");  }),
        Choice("Go back and open the door", { die(p.death) }),
      ]);
     }
    scene("c4train") { 
      bells(1.4); heartbeat(150);
      pound(12, 1.6);
      show("Hold on", "The train is coming. The bells are deafening. Jess pulls you down into the ditch beside the road and wraps both arms around you.\n\nDon't go back. Don't press anything. Just hold on.", [
        Choice("Run back to the car", { die("You run back to the car. You don't even know why.\n\nThe horn is the last thing you hear.") }),
      ]);
      play("trainrumble", [.x(-40), .z(-6), .gain(0.6), .to(-6, 0, 6), .toSec(20)]);
      after(2000, { play("trainhorn", [.x(-30), .z(-6), .gain(1)]) });
      after(4000, { play("hello", [.z(12), .lowpass(2500), .gain(1.6), .rate(0.8)]) });
      after(7500, { play("me", [.z(12), .lowpass(2500), .gain(1.6), .rate(0.85)]) });
      after(9000, { play("trainhorn2", [.x(-15), .z(-4), .gain(1.4)]) });
      after(11500, { play("comeout", [.z(12), .lowpass(2500), .gain(1.6), .rate(0.7)]) });
      after(14500, { play("trainhorn", [.x(-6), .z(2), .gain(2.2)]) });
      after(15500, { play("scream", [.z(12), .gain(opts.soft ? 0.4 : 1.2), .rate(0.6), .lowpass(2500)]) });
      after(19000, {  pound(0); bells(0); crash(); play("scream", [.z(10), .gain(opts.soft ? 0.3 : 1), .rate(0.5), .lowpass(1500)]);  });
      after(19300, { play("trainrumble", [.x(-4), .z(10), .gain(1.6), .to(40, 0, 10), .toSec(14)]) });
      after(21000, { heartbeat(100) });
      after(30000, { heartbeat(70) });
      after(34000, {  heartStop(); birds(true);  });
      after(37000, { play("c4_gone", [.x(-0.4), .z(-0.2), .gain(1.3)]) });
      after(37500 + len("c4_gone"), { go("c4end") });
     }
    scene("c4end") { 
      offCh4(); birds(true);
      music("m_rest", 0.3, 6);
      markDone(4); markEnding("escape");
      show("Ending: Escape", "The train is gone. Where the car was, there's twisted metal scattered down a hundred yards of track. And silence. Real silence.\n\nJess is laughing and crying at the same time. “It's gone. It's really gone. We did it.”\n\nYou sit together in the wet grass while the sun comes up. For the first time in three nights, nothing is breathing behind you.\n\nYou escaped.\n\nThank you for playing Still Here.", [
        Choice("Listen to the morning news", to("c4news")),
        Choice("Play the Interlude: The Station", to("i1")),
        Choice("Main menu", to("title")),
        Choice("Credits", to("credits")),
      ]);
     }
    scene("c4news") { @MainActor in 
      birds(true);
      music("m_rest", 0.08, 2);
      listening();
      try await wait(1500);
      radio(0.03);
      play("news2", [.x(0.5), .z(-0.8), .phone(true), .gain(1.5)]);
      try await wait(len("news2") + 800);
      radio(0);
      show("Morning news", "“In local news, the seven fifteen freight train struck an abandoned car at the Route Nine crossing early this morning. The driver of the train was not hurt. Police say no one was inside the vehicle.\n\nThey also say all four doors were still locked... and that the windows had been scratched... from the inside.”", [
        Choice("Play the Interlude: The Station", to("i1")),
        Choice("Main menu", to("title")),
        Choice("Credits", to("credits")),
      ]);
     }
    scene("i1", true) { @MainActor in 
      toldTruth = 0;
      music("m_drone", 0.14, 4); birds(true); heartbeat(0);
      listening();
      try await wait(2000);
      siren(14, [-40, 0, -20], [-4, 0, -6]);
      try await wait(11000);
      birds(false);
      carDoor(-3); conc(4, [.from(-4, 0, -6), .to(-2, 0, -4), .gap(0.4), .gain(0.8)]);
      try await wait(1500);
      play("i_cop1", [.x(-2.5), .z(-5), .gain(1.4)]);
      try await wait(len("i_cop1") + 1500);
      gravel(5, [.from(-2, 0, -4), .to(-0.8, 0, -1.6), .gap(0.5)]);
      try await wait(3000);
      play("i_cop2", [.x(-0.8), .z(-1.6), .gain(1.3)]);
      try await wait(len("i_cop2") + 600);
      show("Interlude: The Station", "Sirens. Flashing lights you can feel on your eyelids. A car door, boots on the gravel, and a young officer, his voice cracking:\n\n“Police! Hands where I can see them! Both of you, stay on the ground!”\n\nHe comes closer, slowly. He looks at what's left of the car. Then at you.\n\n“Was anybody else in that car?”", [
        Choice("Tell the truth: “Yes. Something was in there with us.”", {  toldTruth += 1; go("i2");  }),
        Choice("Lie: “No. Nobody.”", to("i2")),
        Choice("Say nothing", to("i2")),
      ]);
     }
    scene("i2") { @MainActor in 
      listening();
      try await wait(1200);
      play("i_cop3", [.x(-0.8), .z(-1.4), .gain(1.2)]);
      try await wait(len("i_cop3") + 800);
      carDoor(1); try await wait(700); carDoor(-1);
      engine(0.3); music("m_drone", 0.1, 3);
      try await wait(5000);
      squelch();
      try await wait(400);
      play("i_disp1", [.x(0.4), .z(-0.8), .phone(true), .gain(1.5)]);
      try await wait(len("i_disp1") + 700);
      play("i_cop4", [.x(-0.4), .z(-0.9), .gain(1.2)]);
      try await wait(len("i_cop4") + 1500);
      squelch();
      try await wait(300);
      play("i_disp2", [.x(0.4), .z(-0.8), .phone(true), .gain(1.5)]);
      try await wait(len("i_disp2") + 1500);
      heartbeat(90);
      show("The cruiser", "The back seat of the police car smells like old coffee. Jess sits close to you. Closer than she needs to.\n\nThe radio crackles: “Unit twelve, dispatch. Confirm you are transporting three from the Route Nine crossing.”\n\nThe officer frowns. “Negative, dispatch. Two. I've got two.”\n\nA long pause. Then: “Copy, unit twelve. Three.”\n\nThe officer looks at you in the mirror. Then at the empty space beside you. He doesn't say another word for the rest of the drive.", [
        Choice("Continue", to("i3")),
      ]);
     }
    scene("i3", true) {  qIdx = 0; go("iq");  }
}

func registerStory5() {
    scene("iq") { @MainActor in 
      let q = Q[qIdx];
      engine(0); hum(0.04); music("m_drone", 0.08, 3); heartbeat(0);
      listening();
      if (qIdx == 0) {
        try await wait(1500);
        play("dooropen", [.x(1), .z(-2.5), .gain(1)]);
        conc(4, [.from(1, 0, -2.5), .to(0.2, 0, -1.2), .gap(0.55)]);
        try await wait(2600);
        play("doorclose", [.x(1), .z(-2.5), .gain(0.8)]);
        try await wait(1200);
      } else { try await wait(800); }
      play(q.clip, [.x(0), .z(-1.1), .gain(1.3)]);
      try await wait(len(q.clip) + 500);
      show(q.title, q.text, q.answers.map({ (label, truth) in (Choice(label, { @MainActor in 
        toldTruth += truth;
        clearScene(); listening();
        try await wait(800);
        play("i_r2", [.x(0), .z(-1.1), .gain(1.2)]);
        try await wait(len("i_r2") + 700);
        qIdx += 1;
        go(qIdx < Q.length ? "iq" : "itape");
       })) }));
     }
    scene("itape") { @MainActor in 
      hum(0.04);
      listening();
      try await wait(800);
      play("i_r5", [.x(0), .z(-1.1), .gain(1.3)]);
      try await wait(len("i_r5") + 800);
      play("unlock", [.x(0.3), .z(-0.8), .gain(1)]);
      radio(0.03);
      try await wait(1200);
      play("j_incar", [.x(0.3), .z(-0.8), .phone(true), .gain(1.4)]);
      try await wait(len("j_incar") + 800);
      for i in upTo(2) { play("breath", [.x(0.3), .z(-0.8), .phone(true), .delay(i * 1.3), .gain(1.4)]); }
      try await wait(3000);
      play("thanks", [.x(0.3), .z(-0.8), .phone(true), .gain(1.6)]);
      try await wait(len("thanks") + 1500);
      for i in upTo(4) { play("lock", [.x(0.3), .z(-0.8), .phone(true), .delay(i * 0.05), .gain(1.2)]); }
      try await wait(1500);
      play("c4_you", [.x(0.3), .z(-0.8), .phone(true), .gain(1.6)]);
      try await wait(len("c4_you") + 600);
      radio(0);
      play("unlock", [.x(0.3), .z(-0.8), .gain(1)]);
      try await wait(1500);
      play("i_r6", [.x(0), .z(-1.1), .gain(1.3)]);
      try await wait(len("i_r6") + 1200);
      play("i_r7", [.x(0), .z(-1.3), .gain(1.2)]);
      try await wait(len("i_r7") + 300);
      conc(4, [.from(0.2, 0, -1.2), .to(1, 0, -2.5), .gap(0.5)]);
      try await wait(2200);
      play("doorclose", [.x(1), .z(-2.5), .gain(1)]);
      buzzer();
      try await wait(1500);
      show("The tape", "“I want you to listen to something. That car had a dash camera. The lens was cracked, but the microphone still works.”\n\nHe presses play. Jess, whispering: “It's in the car with us. Isn't it.” Breathing. A third voice: “Thank you... for opening the door.” Four locks dropping. Then your own voice, begging to be let out.\n\nRuiz stops the tape. “That's my problem. Two people in that car. Three voices on this tape. And at seven fourteen this morning, after you two got out, somebody inside that car starts begging to be let out. In your voice.”\n\nHe stands up. “Stay here. I'm going to go talk to your friend.”\n\nThe door closes. The lock buzzes. You're alone.", [
        Choice("Wait", to("i4")),
      ]);
     }
    scene("i4", true) { @MainActor in 
      doorSeq = Math.random() < 0.5 ? ["fakeRuiz", "real"] : ["fakeRuiz", "fakeJess", "real"];
      doorIdx = 0;
      hum(0.04); heartbeat(0); music("m_drone", 0.06, 3);
      listening();
      try await wait(6000);
      hum(0); musicCut(); boom();
      try await wait(2500);
      play("unlock", [.x(1), .z(-2.5), .gain(1.2)]);
      try await wait(2500);
      radio(0.04); squelch(0, -1.5);
      try await wait(500);
      play("i_r8", [.x(0), .y(1.5), .z(-1), .phone(true), .gain(1.5)]);
      try await wait(len("i_r8") + 600);
      radio(0);
      heartbeat(100);
      show("Blackout", "The lights die. The hum stops. Total dark.\n\nThen a click from the door. The lock. Without power, the doors unlock.\n\nThe intercom crackles. Ruiz: “Power's out across the whole building. Stay in your seat. Don't open that door for anyone but me. When I come back, I'll knock and say, ‘It's Ruiz.’”", [
        Choice("Wait for him", to("idoor")),
      ]);
     }
    scene("idoor") { @MainActor in 
      let v = doorSeq[doorIdx];
      heartbeat(105 + doorIdx * 10);
      listening();
      try await wait(3000 + Math.random() * 3000);
      if (v == "real") {
        conc(7, [.from(8, 0, -6), .to(1, 0, -2.6), .gap(0.33), .gain(1.1)]);
        play("keys", [.x(4), .z(-4), .delay(0.8)]); play("keys", [.x(1.5), .z(-2.8), .delay(2)]);
        after(1000, { squelch(3, -4) }); after(2200, { squelch(1.2, -2.8) });
        try await wait(2600);
        play("knock", [.x(1), .z(-2.5), .gain(1.6), .rate(1.2)]);
        try await wait(1200);
        play("i_r10", [.x(1), .z(-2.5), .gain(1.4), .lowpass(5000)]);
        try await wait(len("i_r10") + 500);
      } else {
        play("knock", [.x(1), .z(-2.5), .gain(1.1)]);
        try await wait(1800);
        play(v == "fakeRuiz" ? "i_r9" : "jess_code", [.x(1), .z(-2.5), .phone(true), .gain(1.6)]);
        try await wait(len(v == "fakeRuiz" ? "i_r9" : "jess_code") + 1200);
      }
      show("Someone at the door", DOOR_TEXT[v], [
        Choice("Open the door", { v == "real" ? go("i5") : die(DOOR_DEATH[v]) }),
        Choice("Stay in your seat", { 
          if (v == "real") { go("i5"); return; }
          clearScene(); listening();
          play("scratch", [.x(1), .z(-2.4), .gain(1.2), .rate(0.8)]);
          play("scratch", [.x(1), .z(-2.4), .gain(1.2), .rate(0.7), .delay(1.1)]);
          after(5000, {  doorIdx += 1; go("idoor");  });
         }),
      ]);
     }
    scene("i5", true) { 
      junction = 0;
      heartbeat(110);
      show("The hallway", "Ruiz pulls you into the corridor and grips your arm. A flashlight clicks on. Somewhere in the building, a phone is ringing and ringing.\n\nThen he stops. Above you, in the ceiling, something heavy shifts its weight inside the air vents.\n\nAt each corner, listen for which side of the ceiling it's crawling in. Go the other way.", [
        Choice("Follow Ruiz", {  play("unlock", [.x(0.3), .z(-0.3)]); junctionNext();  }),
      ]);
     }
    scene("icell") { @MainActor in 
      listening();
      try await wait(2000);
      play("trunk", [.x(-1.6), .z(-0.5), .gain(1.2), .rate(1.4)]); play("lock", [.x(-1.6), .z(-0.5), .gain(1.2), .delay(0.3)]);
      try await wait(900);
      play("i_p1", [.x(-1.4), .z(-0.4), .gain(1.4)]);
      try await wait(len("i_p1") + 600);
      show("The cells", "You pass the holding cells. Bars rattle. A man's voice, old and shaking, from the dark:\n\n“Hey. Hey, you. It's in the vents. It's been copying the officers all night. Don't answer it. Don't answer anything that calls your name.”", [
        Choice("Keep moving", junctionNext),
      ]);
     }
    scene("icall") { @MainActor in 
      listening();
      try await wait(2500);
      play("c4_fakejess", [.x(-3), .z(1.5), .phone(true), .gain(1.4), .lowpass(3000)]);
      try await wait(len("c4_fakejess") + 600);
      show("A voice in the dark", "From a dark office behind you, Jess's voice, sobbing:\n\n“Let me out! Please! It's me, it's Jess! It tricked you, she's the one out there! Open the door!”\n\nRuiz's hand tightens on your arm. “Your friend's in the lobby,” he whispers. “I left her there myself.”", [
        Choice("Go to the voice", { die("You pull free and run toward her voice.\n\nRuiz was right. Jess was in the lobby. Whatever was calling you was not.") }),
        Choice("Keep following Ruiz", junctionNext),
      ]);
     }
    scene("iradio") { @MainActor in 
      listening();
      try await wait(1800);
      squelch(0.4, -0.3);
      try await wait(400);
      play("i_disp3", [.x(0.4), .z(-0.3), .phone(true), .gain(1.5)]);
      try await wait(len("i_disp3") + 1200);
      play("i_r12", [.x(0.4), .z(-0.4), .gain(1.3)]);
      try await wait(len("i_r12") + 800);
      show("The radio", "Ruiz's radio crackles on his belt. The dispatcher, calm and flat:\n\n“Ruiz. Bring them down to the basement.”\n\nRuiz goes very still. Then he whispers, “We don't have a basement.”\n\nHe switches the radio off. And starts to run.", [
        Choice("Run", to("i6")),
      ]);
     }
    scene("i6") { @MainActor in 
      heartbeat(120);
      listening();
      conc(10, [.from(0, 0, 0), .to(0, 0, -6), .gap(0.22), .gain(1)]);
      try await wait(2600);
      play("dooropen", [.z(-3), .gain(1.2), .rate(1.3)]);
      try await wait(1200);
      conc(5, [.from(-3, 0, -5), .to(-0.4, 0, -0.6), .gap(0.25), .gain(0.9)]);
      try await wait(1600);
      heartbeat(90);
      play("i_j1", [.x(-0.3), .z(-0.3), .gain(1.3)]);
      try await wait(len("i_j1") + 600);
      show("The lobby", "Grey morning light through the front windows. The lobby. And Jess, running at you out of the dark.\n\nShe throws her arms around you and holds on.\n\n“Oh, thank God. I thought it took you. I thought... Don't you ever do that to me again.”", [
        Choice("Hold her", {  closeness += 1; go("i6b");  }),
        Choice("Tell her: “I'm okay. I'm here.”", {  closeness += 1; go("i6b");  }),
        Choice("Pull away gently", to("i6b")),
      ]);
     }
    scene("i6b") { @MainActor in 
      listening();
      try await wait(1500);
      play("keys", [.x(0.8), .z(-1), .gain(1.2)]);
      try await wait(800);
      play("i_r13", [.x(0.8), .z(-1.1), .gain(1.3)]);
      try await wait(len("i_r13") + 700);
      show("Elk Ridge", "Ruiz presses a set of keys into your hand. His own car.\n\n“There's a cabin. My brother's. Up past Elk Ridge. No phone. No neighbors. Nobody's going to find you up there.”\n\n" + str((toldTruth >= 2 ? "He looks at you for a long moment. “I believe you,” he says quietly. “God help me, I believe you.”" : "He doesn't ask any more questions. He doesn't need to anymore.")), [
        Choice("Go", to("i7")),
      ]);
     }
    scene("i7") { @MainActor in 
      listening();
      carDoor(0.9); try await wait(600); carDoor(-0.9);
      try await wait(800);
      engine(0.3); music("m_rest", 0.16, 6);
      try await wait(6000);
      play("i_j2", [.x(-0.6), .z(-0.3), .gain(1.2)]);
      try await wait(len("i_j2") + 4000);
      squelch(0.4, -0.8);
      try await wait(400);
      music("m_rest", 0, 1);
      play("i_disp2", [.x(0.4), .z(-0.8), .phone(true), .gain(1.5)]);
      try await wait(len("i_disp2") + 1500);
      markDone(5);
      show("End of the Interlude", "Jess drives. You watch the town disappear behind you. After a long time she says, softly:\n\n“Hey. Thank you. For not letting go of my hand.”\n\nRuiz's police radio is still bolted under the dashboard. It crackles once, by itself:\n\n“Copy, unit twelve. Three.”\n\nNext: the cabin.", [
        Choice("Play Chapter Five: The Cabin", to("c5")),
        Choice("Main menu", to("title")),
        Choice("Credits", to("credits")),
      ]);
     }
    scene("c5", true) { @MainActor in 
      c5asked = false; c5wait = false; c5letring = false;
      offCh4(); birds(false); rain(0); heartbeat(0);
      music("m_rest", 0.12, 5); wind(0.06);
      engine(0.25);
      listening();
      try await wait(5000);
      gravel(6, [.from(0, 0, -0.5), .to(0, 0, -0.5), .gap(0.25), .gain(0.7)]);
      engine(0);
      try await wait(2000);
      carDoor(0.9); try await wait(500); carDoor(-0.9);
      gravel(6, [.from(0, 0, 0), .to(0, 0, -3), .gap(0.5), .gain(0.8)]);
      try await wait(3200);
      play("creak", [.z(-1.5), .gain(1.2)]);
      try await wait(2000);
      play("c5_arrive", [.x(-0.8), .z(-0.8), .gain(1.2)]);
      try await wait(len("c5_arrive") + 700);
      show("Chapter Five: The Cabin", "Ruiz's directions take you up a dirt road that turns to mud, then to two ruts in the pine needles. The cabin is one room: a stone fireplace, two old couches, a woodstove, a shed out back with a generator. No phone. No neighbors. Just wind in the pines.\n\nJess drops her bag and stands in the doorway for a long time.\n\n“It's perfect. Nobody for miles. Just us.”", [
        Choice("Light the fire", to("c5fire")),
      ]);
     }
}

func registerStory6() {
    scene("c5fire") { @MainActor in 
      wind(0.05); music("m_rest", 0.1, 3);
      listening();
      play("chop", [.x(0.8), .z(-1.5), .gain(0.8), .rate(1.4)]);
      try await wait(1200);
      fire(0.6);
      try await wait(5000);
      play("c5_aunt", [.x(-0.6), .z(-0.4), .gain(1.2)]);
      try await wait(len("c5_aunt") + 800);
      show("The fire", "The fire catches. For the first time in days, you're warm. Jess sits beside you on the floor, knees pulled up, staring into the flames.\n\n“She was my aunt. Mrs. Alvarez. I was staying with her that week. I heard it take her. I heard it practicing her voice in the dark, over and over. That's how I knew what it was.\n\nAnd then I heard it say your name.”", [
        Choice("Take her hand", {  closeness += 1; go("c5glad");  }),
        Choice("Ask: “Why did you call me? You didn't even know me.”", {  c5asked = true; go("c5glad");  }),
        Choice("Listen quietly", to("c5glad")),
      ]);
     }
    scene("c5glad") { @MainActor in 
      listening();
      try await wait(2500);
      play("c5_glad", [.x(-0.5), .z(-0.3), .gain(1.2)]);
      try await wait(len("c5_glad") + 700);
      show("The fire", str((c5asked ? "“Because it said your name like it was hungry,” she says. “And I couldn't let it eat one more person I could have warned.”\n\n" : "")) + "She's quiet for a while. The fire pops. Then, almost too soft to hear:\n\n“Can I tell you something stupid? I'm glad it was you.”", [
        Choice("“I'm glad it was you too.”", {  closeness += 1; go("c5secret");  }),
        Choice("Lean your head on her shoulder", {  closeness += 1; go("c5secret");  }),
        Choice("Laugh softly and say nothing", to("c5secret")),
      ]);
     }
    scene("c5secret") { @MainActor in 
      secretWord = pick(["river", "sparrow", "lantern"]);
      listening();
      try await wait(2000);
      play("c5_secret", [.x(-0.3), .z(-0.15), .gain(1.1)]);
      try await wait(len("c5_secret") + 600);
      play("seat", [.x(-0.2), .z(-0.1), .gain(0.6)]);
      try await wait(1500);
      show("Her hand", "“If we ever get split up... I'm not saying this out loud. It hears everything. Give me your hand.”\n\nShe turns your hand palm up. With one fingertip, slowly, without making a single sound, she traces letters into your skin:\n\n" + str(SPELL[secretWord]) + "\n\n" + secretWord.capitalizedFirst + ".\n\nShe closes your fingers over it. That's how you'll know it's her. Never say it out loud.", [
        Choice("Remember the word: " + str(secretWord), to("c5night")),
      ]);
     }
    scene("c5night") { 
      fire(0.15); wind(0.07); music("m_drone", 0.06, 6); heartbeat(0);
      show("The first night", "Later, the fire burns down to orange coals. Jess falls asleep on the couch beside you, one hand still curled around yours. Her breathing is slow and even.\n\nYou don't sleep. You listen.\n\nIf anything happens tonight: don't wake her. Don't make a sound. Don't touch anything until it's gone.", [
        Choice("Wake Jess", { die("You shake her awake. She gasps your name, out loud, into the dark.\n\nOutside, something says it back.") }),
        Choice("Go to the window", { die("You get up and go to the window. The floorboards creak under you.\n\nOn the other side of the glass, something is already looking for you.") }),
      ]);
      after(6000, owl);
      after(11000, { owl() });
      // footsteps circling the cabin, then tapping on the glass
      let n = 16.0;
      for i in upTo(n) {
        let a = -Math.PI / 2 + (i / n) * Math.PI * 2;
        after(16000 + i * 1100, { play("gravel" + str((i % 3)), [.x(Math.cos(a) * 4.5), .z(Math.sin(a) * 4.5), .gain(0.8), .lowpass(2500)]) });
      }
      after(20000, { heartbeat(110) });
      after(34000, {  for i in upTo(3) { play("tap" + str((i % 2)), [.x(-2.5), .z(-1), .delay(i * 0.6), .gain(1.4)]); }  });
      after(40000, {  for i in upTo(3) { play("tap" + str((i % 2)), [.x(2.5), .z(0.5), .delay(i * 0.6), .gain(1.6)]); }  });
      after(46000, { play("hello", [.x(2.5), .z(0.5), .lowpass(2500), .gain(1.3)]) });
      after(54000, {  for i in upTo(3) { play("breath", [.x(2.4), .z(0.6), .delay(i * 1.3), .gain(1.1), .lowpass(3000)]); }  });
      after(62000, { gravel(6, [.from(2.5, 0, 1), .to(8, 0, 10), .gap(0.8), .gain(0.7)]) });
      after(70000, {  heartbeat(80); owl();  });
      after(76000, {  heartStop(); go("c5weeks");  });
     }
    scene("c5weeks", true) { @MainActor in 
      fire(0); wind(0.03); music("m_rest", 0.14, 4); engine(0.05);
      listening();
      try await wait(1500);
      birds(true);
      for i in upTo(4) { play("chop", [.x(2.5), .z(-4), .delay(1 + i * 1.6), .gain(0.9), .rate(0.9 + Math.random() * 0.2)]); }
      try await wait(9000);
      birds(false); fire(0.5);
      try await wait(3000);
      play("c5_love", [.x(-0.4), .z(-0.2), .gain(1.2)]);
      try await wait(len("c5_love") + 800);
      show("Three weeks", "Three weeks go by. Nothing knocks. Nothing breathes behind you.\n\nYou split wood. Jess teaches you a card game she's sure she invented. She laughs at your terrible jokes. The generator hums behind the cabin every night, and every night you both sleep a little longer.\n\nThen, one night by the fire, she says it:\n\n“I love you. I know that's crazy. I don't care.”", [
        Choice("Say it back: “I love you too.”", {  closeness += 2; go("c5after");  }),
        Choice("Kiss her", {  closeness += 2; go("c5after");  }),
        Choice("“I... need a little more time.”", {  c5wait = true; go("c5after");  }),
      ]);
     }
    scene("c5after") { @MainActor in 
      listening();
      try await wait(4000);
      wind(0.08);
      try await wait(3000);
      show("Three weeks", str((c5wait ? "“Okay,” she says, and smiles anyway. “I'll wait.”\n\n" : "For a while, the whole world is just the two of you and the fire.\n\n")) + "Outside, far off in the trees, every insect, every bird, every sound of the night goes quiet at the same moment.\n\nAs if something out there was listening.", [
        Choice("Continue", to("c5storm")),
      ]);
     }
    scene("c5storm", true) { @MainActor in 
      music("m_drone", 0.12, 4); fire(0.3); wind(0.12); rain(0.3, true); engine(0.05); heartbeat(0);
      thunderSoon(3000);
      listening();
      try await wait(7000);
      engine(0.12); try await wait(500); engine(0.02); try await wait(400); engine(0.1); try await wait(700); engine(0);
      fire(0.15);
      try await wait(2500);
      play("c5_storm", [.x(-0.5), .z(-0.6), .gain(1.2)]);
      try await wait(len("c5_storm") + 500);
      play("creak", [.z(-2), .gain(1.2), .rate(1.2)]); rain(0.5, true);
      gravel(6, [.from(0, 0, -2), .to(4, 0, 6), .gap(0.4), .gain(0.8)]);
      try await wait(2800);
      play("doorclose", [.z(-2), .gain(1)]); rain(0.3);
      try await wait(1500);
      heartbeat(90);
      show("The storm", "A storm rolls over the ridge after midnight. Rain on the roof like gravel. The fire is down to embers.\n\nThe generator coughs, sputters, and dies. Everything goes dark.\n\nJess pulls on her boots. “The generator's out. I'll be right back. Lock the door behind me. I love you.”\n\nThe door opens. Wind and rain. Her footsteps fade toward the shed. The door swings shut.", [
        Choice("Lock the door", {  play("lock", [.z(-2), .gain(1.4)]); c5visits = Math.random() < 0.5 ? ["fakeJess", "real"] : ["fakeJess", "fakeYou", "real"]; c5idx = 0; go("c5door");  }),
      ]);
     }
    scene("c5door") { @MainActor in 
      let v = c5visits[c5idx];
      heartbeat(100 + c5idx * 10);
      listening();
      try await wait(4000 + Math.random() * 4000);
      if (v == "real") {
        engine(0.12);
        try await wait(1500);
        gravel(6, [.from(4, 0, 6), .to(0.5, 0, -1.8), .gap(0.3), .gain(1)]);
        try await wait(2200);
        play("knock", [.z(-2), .gain(1.7), .rate(1.3)]); play("knock", [.z(-2), .gain(1.7), .rate(1.3), .delay(0.5)]);
        try await wait(1000);
        play("c5_realknock", [.z(-2), .gain(1.4), .lowpass(5000)]);
        try await wait(len("c5_realknock") + 500);
      } else {
        play("knock", [.z(-2), .gain(1.1)]);
        try await wait(1800);
        play(v == "fakeJess" ? "c5_fake" : "me", [.z(-2), .gain(1.4), .lowpass(5000)]);
        try await wait(len(v == "fakeJess" ? "c5_fake" : "me") + 1200);
      }
      c5doorChoices(v, C5_TEXT[v]);
     }
    scene("c5bad") { @MainActor in 
      listening();
      try await wait(3000);
      play("knock", [.z(-2), .gain(1)]);
      try await wait(5000);
      play("jess_scream", [.x(2), .z(3), .gain(1.4), .lowpass(4000)]);
      engine(0);
      try await wait(6000);
      silenceAll(); offCh5();
      markEnding("shed");
      show("Ending: The Shed", "You stayed quiet. You were so careful.\n\nThe pounding stops. The generator dies. And then there's only the rain.\n\nIn the morning, the shed door is open. Inside, someone has written a single word on the wall, over and over, in mud: " + str(secretWord) + ".", [
        Choice("Try again from the last checkpoint", { go(checkpoint) }),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c5shed") { @MainActor in 
      engine(0.1);
      listening();
      play("lock", [.z(-2), .gain(0.8), .rate(1.3)]);
      try await wait(600);
      play("doorclose", [.z(-2), .gain(1.2)]);
      play("lock", [.z(-2), .gain(1.4), .delay(0.4)]);
      rain(0.2);
      try await wait(2500);
      play("c5_shed", [.x(-0.3), .z(-0.2), .gain(1.3)]);
      try await wait(len("c5_shed") + 700);
      heartbeat(95);
      show("Inside", "Jess falls through the door, soaked and shaking, and you lock it behind her.\n\n“It was in the shed with me. It talked to me in the dark. In your voice. It said it loved me.”", [
        Choice("Hold her until she stops shaking", {  closeness += 1; go("c5dawn");  }),
        Choice("“It's not getting in. I won't let it.”", {  closeness += 1; go("c5dawn");  }),
        Choice("Check the windows", to("c5dawn")),
      ]);
     }
    scene("c5dawn") { @MainActor in 
      heartbeat(0); rain(0.02); wind(0.03); fire(0.4);
      music("m_rest", 0.12, 6);
      listening();
      try await wait(4000);
      birds(true);
      let close = closeness >= 3;
      if (close) { play("c5_together", [.x(-0.3), .z(-0.15), .gain(1.2)]); try await wait(len("c5_together") + 1000); }
      else { try await wait(2500); }
      show("Morning", str((close ? "Dawn comes grey and wet. Neither of you slept. Jess's head is on your shoulder, her hand still in yours.\n\n“Whatever happens next,” she whispers, “we do it together.”" : "Dawn comes grey and wet. Neither of you slept. Jess sits close beside you, staring at the door.")) + "\n\nThe storm has passed. The birds are back.\n\nAnd then, from the closet at the back of the cabin, a phone starts to ring.\n\nThere is no phone in this cabin.", [
        Choice("Find the phone and answer it", { go("c5phone") }),
        Choice("Let it ring", {  c5letring = true; go("c5phone");  }),
      ]);
      after(5000, { ring(20, -2.5, 1) });
     }
    scene("c5phone") { @MainActor in 
      birds(false); music("m_rest", 0, 2);
      listening();
      if (c5letring) {
        ring(4, -2.5, 1);
        try await wait(16000);
        tone([.f(1000), .dur(0.6), .gain(0.15), .x(-2.5), .z(1)]);
        try await wait(1200);
        play("c5_learning", [.x(-2.5), .z(1), .phone(true), .gain(1.8)]);
        try await wait(len("c5_learning") + 1500);
      } else {
        ringStop();
        play("dooropen", [.x(-2.5), .z(1), .gain(0.8)]);
        try await wait(1200);
        play("unlock", [.x(-0.4), .z(-0.2), .gain(1)]);
        try await wait(1200);
        play("c5_learning", [.x(0.15), .z(-0.05), .phone(true), .gain(1.6)]);
        try await wait(len("c5_learning") + 1500);
      }
      markDone(6);
      silenceAll(); offCh5();
      show("End of Chapter Five", str((c5letring ? "It rings and rings. Then an old answering machine you didn't know was there clicks on, and plays a message to the empty room." : "In the closet, under a pile of blankets, an old phone you've never seen before. Its cord isn't plugged into anything. You pick it up.")) + "\n\nA whisper, tender and wrong:\n\n“I love you. I love you. I love you. I'm learning.”\n\nIt isn't copying anymore. It's practicing.", [
        Choice("Play Chapter Six: The Tapes", to("c6")),
        Choice("Main menu", to("title")),
        Choice("Credits", to("credits")),
      ]);
     }
}

func registerStory7() {
    scene("c6", true) { @MainActor in 
      tapesHeard = [];
      silenceAll(); music("m_air", 0.1, 5); wind(0.06); fire(0.4); heartbeat(0);
      listening();
      try await wait(3000);
      engine(0.2);
      try await wait(4000);
      gravel(5, [.from(3, 0, -8), .to(1, 0, -5), .gap(0.25), .gain(0.6)]); engine(0);
      try await wait(2000);
      carDoor(1.5);
      gravel(6, [.from(1.5, 0, -5), .to(0.3, 0, -2.2), .gap(0.5), .gain(0.9)]);
      play("keys", [.x(0.6), .z(-2.4), .delay(2.5)]); after(3000, { squelch(0.4, -2.3) });
      try await wait(3500);
      play("knock", [.z(-2), .gain(1.5), .rate(1.1)]);
      try await wait(1200);
      try await say2("c6_door", [.z(-2), .gain(1.4), .lowpass(5000)]);
      show("Chapter Six: The Tapes", "Three days after the phone in the closet, you still haven't slept more than an hour at a time. Neither has Jess.\n\nThen, at dusk, headlights on the dirt road. A car door. Footsteps. Keys jangling, and a police radio hissing on someone's belt.\n\nA fist on the door: “It's Ruiz! I drove four hours. Open up. I've got something you need to hear.”", [
        Choice("Open the door", to("c6box")),
        Choice("Listen again before you open it", { 
          clearScene(); listening();
          play("keys", [.x(0.6), .z(-2.2)]); after(600, { squelch(0.4, -2.2) });
          after(2500, { show("Chapter Six: The Tapes", "Keys. A police radio. Boots shifting on the porch. Things a copy wouldn't bother with.\n\nIt's him.", [Choice("Open the door", to("c6box"))]) });
         }),
      ]);
     }
    scene("c6box", true) { @MainActor in 
      fire(0.4);
      listening();
      play("lock", [.z(-2), .gain(1.1)]); try await wait(500);
      play("creak", [.z(-2), .gain(1.1), .rate(1.2)]);
      try await wait(1800);
      play("doorclose", [.z(-2)]); play("lock", [.z(-2), .delay(0.4)]);
      try await wait(1200);
      play("trunk", [.x(0.2), .z(-0.9), .gain(1.3), .rate(0.6), .lowpass(1500)]);
      try await wait(1200);
      try await say2("c6_box", [.x(0.3), .z(-1), .gain(1.3)]);
      c6menu("Ruiz drops a cardboard box on the table. It's full of cassette tapes, each one labeled in fading pen.\n\n“Nineteen eighty-seven. Same town. Same knocking. Eleven people gone. The sheriff recorded everything. Nobody ever listened to these.”\n\nHe sets an old tape player on the table between you.");
     }
    scene("c6t_girl") { @MainActor in 
      listening();
      try await tape("c6_sheriff", 300);
      try await tape("c6_girl");
      if (!tapesHeard.includes("girl")) { tapesHeard.push("girl"); }
      c6menu("A gentle old voice: “Okay, sweetheart. Tell me what happened the night your mom went missing.”\n\nA little girl: “It knocked. And it used Mommy's voice. But Mommy was already in bed. It said, open the door, baby. Mommy never calls me baby.”\n\nJess is gripping the edge of the table.");
     }
    scene("c6t_dj") { @MainActor in 
      listening();
      try await tape("c6_dj1", 200);
      radio(0.12); try await wait(1500); radio(0);
      try await tape("c6_dj2", 200);
      radio(0.18); try await wait(900); radio(0);
      try await tape("c6_dj3");
      if (!tapesHeard.includes("dj")) { tapesHeard.push("dj"); }
      c6menu("A cheerful late-night DJ: “You're listening to K-R-O-D, ninety-four point one, the voice of Elk Ridge! It's two a.m., and we're taking your calls. Caller, you're on the air!”\n\nStatic. Then, confused: “Caller? Hello? That's... that's my voice. Who is this? How are you doing my voice?”\n\nMore static. Then a whisper, still on air: “If anyone's listening... don't call in. It's listening to the station. It's learning everyone at once.”");
     }
    scene("c6t_walter") { @MainActor in 
      listening();
      try await tape("c6_walter1", 300);
      try await tape("c6_walter2");
      if (!tapesHeard.includes("walter")) { tapesHeard.push("walter"); }
      c6menu("An old man, tired, recording a confession: “My name is Walter Hask. I ran the radio station. I'm the one who woke it up. Here's what I know. It can't open a locked door. And it can only use voices it has heard.”\n\nThen, urgent, whispering: “And it can't stand silence. It needs us talking. Talking is how it eats. If you ever find it... don't say a word.”");
     }
    scene("c6after") { @MainActor in 
      listening();
      tapeClick();
      try await wait(2500);
      try await say2("c6_jess", [.x(-0.5), .z(-0.3), .gain(1.3)], 1200);
      try await say2("c6_end", [.x(0.3), .z(-1), .gain(1.3)]);
      show("Forty years", "Nobody speaks for a long time. The fire pops.\n\nJess whispers, “It's been doing this for forty years.”\n\nRuiz stares at the box. “The station's still up there. On the mountain. I don't think it ever left.”\n\nYou all agree to go in the morning. Ruiz takes the couch. Nobody turns off the lamp.", [
        Choice("Try to sleep", to("c6night")),
      ]);
     }
    scene("c6night", true) { @MainActor in 
      fire(0.15); wind(0.05); music("m_drone", 0.06, 6); heartbeat(0);
      listening();
      try await wait(7000);
      tapeClick();
      try await wait(1500);
      radio(0.03);
      play("c5_love", [.x(0.4), .z(-0.6), .phone(true), .gain(1.3)]);
      try await wait(len("c5_love") + 900);
      play("c5_glad", [.x(0.4), .z(-0.6), .phone(true), .gain(1.3)]);
      try await wait(len("c5_glad") + 900);
      radio(0); tapeClick();
      try await wait(2500);
      play("knock", [.z(-2), .gain(1.3)]);
      try await wait(2000);
      heartbeat(120);
      show("The tape player", "You wake up because the tape player clicks on by itself.\n\nIt isn't playing a tape from 1987. It's playing Jess, by the fire, three weeks ago: “I love you. I know that's crazy.” And then: “I'm glad it was you.”\n\nIt was recording you. Every night.\n\nThen a knock at the door. On the couch, Ruiz sits up, confused, and opens his mouth to speak—", [
        Choice("Cover Ruiz's mouth", to("c6hold")),
        Choice("Answer the door: “Who's there?”", { die("“Who's there?” you call.\n\nThe door answers you. In your voice. “Who's there?”") }),
        Choice("Shout: “Go away!”", { die("You shout at it to go away.\n\nIt doesn't. It just learned how you sound when you're scared.") }),
      ]);
     }
    scene("c6hold") { 
      heartbeat(125);
      holdStill("Silence", "You clamp your hand over Ruiz's mouth. His eyes are wide. You shake your head, slowly. Jess is frozen beside you.\n\nWalter said it: it can't stand silence. So give it none.\n\nDon't make a sound. Don't press anything.",
        [("Whisper to Jess", "You lean over and whisper Jess's name, barely a breath.\n\nOutside the door, it whispers her name too. Then it tries the handle."),
         ("Move to the window", "The floorboards creak. Outside, the knocking stops at once. Then it starts again. At the window. Right in front of you.")],
        [(3000, { play("knock", [.z(-2), .gain(1.2)]) }),
         (6000, { play("jess_code", [.z(-2), .phone(true), .gain(1.4)]) }),
         (12000, { play("i_r9", [.z(-2), .gain(1.4), .lowpass(4000)]) }),
         (18000, { play("c4_you", [.z(-2), .gain(1.4), .lowpass(3500)]) }),
         (26000, {  for i in upTo(3) { play("breath", [.z(-1.8), .delay(i * 1.3), .gain(1.2)]); }  }),
         (32000, { play("c6_walter2", [.z(-2), .gain(1.2), .lowpass(3000), .rate(0.85)]) }),
         (44000, { gravel(6, [.from(0, 0, -3), .to(-6, 0, -10), .gap(0.8), .gain(0.7)]) }),
         (50000, { heartbeat(80) })],
        55000, { 
          heartStop(); markDone(7);
          show("End of Chapter Six", "It tried Jess's voice. It tried Ruiz's voice, while Ruiz sat right next to you with your hand over his mouth. It tried yours. It even tried Walter's.\n\nThen, finally, the footsteps walked away into the trees.\n\nRuiz pulls your hand down, very slowly. He doesn't say anything. He just nods.\n\nIn the morning, you drive up the mountain.", [
            Choice("Play Chapter Seven: The Radio Tower", to("c7")),
            Choice("Main menu", to("title")),
          ]);
         });
     }
    scene("c7", true) { @MainActor in 
      silenceAll(); music("m_drone", 0.12, 5); wind(0.15); heartbeat(0);
      engine(0.3);
      listening();
      try await wait(6000);
      engine(0);
      try await wait(1500);
      carDoor(-0.9); carDoor(0.9);
      try await wait(1500);
      tone([.f(600), .dur(0.2), .gain(0.04), .x(3), .y(8), .z(-12)]); after(2000, { tone([.f(600), .dur(0.2), .gain(0.04), .x(3), .y(8), .z(-12)]) });
      try await say2("c7_jess1", [.x(-0.6), .z(-0.3), .gain(1.2)], 800);
      try await say2("c7_ruiz1", [.x(0.7), .z(-0.4), .gain(1.3)]);
      show("Chapter Seven: The Radio Tower", "The road ends in snow. Above you, the old KROD station: a concrete box, and a steel tower climbing into the clouds. Wind sings through the cables.\n\nJess whispers: “That's it. The tower. The red light's still blinking. After forty years.”\n\nRuiz, low: “Station's been dead since eighty-seven. No power lines up here. So why is that light on?”", [
        Choice("Go inside", to("c7tune")),
      ]);
     }
    scene("c7tune") { 
      dial = 50; foundStations = [];
      let pool = [10.0, 20, 30, 40, 60, 70, 80, 90]; targets = shuffle(pool).slice(0, 3);
      music("m_drone", 0.06, 3); wind(0.05);
      radio(0.12);
      show("The radio", "Inside, everything is dust and dead equipment. But on the main desk, an old radio receiver hums with power it shouldn't have.\n\nRuiz turns it toward you. “Somewhere in that static, it's talking. Find it.”\n\nTurn the dial up or down. The static gets quieter as you get close to a broadcast, and you'll start to hear it underneath. There are three to find. The dial goes from 0 to 100, and starts at 50.", tuneChoices());
     }
}

func registerStory8() {
    scene("c7stairs", true) { 
      climbStep = 0; climbStrikes = 0; gustLive = false;
      wind(0.04); heartbeat(100);
      climbShow("All three broadcasts are coming from the same place: the DJ booth, at the top of a metal staircase that rattles at the slightest touch.\n\nAnd something in the station is listening for footsteps.\n\nOnly move when the wind gusts. The tower groans and covers you. Three flights.");
      gustLoop(9000);
     }
    scene("c7booth", true) { @MainActor in 
      wind(0.08); heartbeat(105);
      listening();
      play("dooropen", [.z(-1.5), .gain(0.8)]);
      try await wait(2000);
      try await say2("c7_ruiz2", [.x(0.5), .z(-0.4), .gain(1.3)]);
      var choices = [Choice("Pull the breaker", to("c7dark"))];
      if (!tapesFound.includes("t3")) { choices.push(Choice("Search the DJ's desk first", { @MainActor in 
        clearScene(); listening();
        play("seat", [.z(-0.6), .gain(0.9)]);
        try await wait(1500);
        findTape("t3");
        try await tape("t3");
        show("The booth", "In the DJ's desk drawer, a cassette labeled in marker: “NOTE TO SELF.” A tired voice: “Note to self. Stop taking calls after two.”\n\nHe didn't.", [Choice("Pull the breaker", to("c7dark"))]);
       })); }
      show("The booth", "The DJ booth. A microphone still on its stand, the ON AIR light glowing red. Dust on everything except the microphone.\n\nRuiz finds a huge lever on the wall and whispers: “Main breaker. If I pull this, every radio in this valley goes dark. Including whatever's using them.”", choices);
     }
    scene("c7dark") { @MainActor in 
      listening();
      play("trunk", [.x(0.6), .z(-0.5), .gain(1.8), .rate(0.5)]); boom();
      try await wait(1500);
      heartbeat(150);
      scream();
      let voices = ["hello", "awake", "jess_code", "i_r9", "neighbor", "comeout", "c6_dj2", "me"];
      voices.forEachI({ v, i in play(v, [.x(Math.cos(i) * 4), .z(Math.sin(i) * 4), .delay(0.3 + i * 0.25), .gain(1.1), .rate(0.7 + Math.random() * 0.4), .lowpass(3000)]) });
      try await wait(6500);
      stopAll(); heartbeat(0); wind(0);
      try await wait(4000);
      try await say2("c7_jess2", [.x(-0.5), .z(-0.3), .gain(1.2)], 3500);
      try await say2("c7_cr", [.x(0.3), .z(0.2), .gain(1.8)]);
      markDone(8);
      silenceAll();
      show("End of Chapter Seven", "When Ruiz pulls the lever, every speaker in the station screams at once, in every voice it has ever stolen. Then silence. Real silence.\n\nJess, breathless: “Did we do it? Is it gone?”\n\nThe red light on the tower is still blinking. With no power at all.\n\nAnd right behind you, a whisper: “You turned off my mouth. I still have yours.”", [
        Choice("Play Chapter Eight: Mrs. Alvarez", to("c8")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c8", true) { @MainActor in 
      silenceAll(); music("m_air", 0.08, 5); hum(0.03); heartbeat(0);
      listening();
      try await wait(2000);
      tone([.f(880), .dur(0.3), .gain(0.1), .z(-2)]); tone([.f(660), .dur(0.5), .gain(0.1), .z(-2), .delay(0.3)]);
      conc(6, [.from(0, 0, -3), .to(0, 0, -0.8), .gap(0.45), .gain(0.7)]);
      try await wait(3000);
      try await say2("c8_nurse1", [.x(0.6), .z(-0.8), .gain(1.2)]);
      show("Chapter Eight: Mrs. Alvarez", "A week later, Ruiz calls. Mrs. Alvarez has been found. Alive.\n\nCounty Hospital, third floor, two in the morning. The night nurse meets you at the elevator, keeping her voice low:\n\n“She was found walking on Route Nine at four in the morning. Barefoot. She hasn't said a word to anyone. Except your names.”", [
        Choice("Go to room 312", to("c8room")),
      ]);
     }
    scene("c8room", true) { @MainActor in 
      hum(0.03);
      listening();
      conc(5, [.from(0, 0, 0), .to(1, 0, -3), .gap(0.45), .gain(0.6)]);
      try await wait(2600);
      play("dooropen", [.x(1), .z(-2), .gain(0.8)]);
      monitor(true);
      try await wait(2500);
      try await say2("c8_alv1", [.x(1.2), .z(-0.8), .gain(1.2)]);
      var choices = [
        Choice("Let Jess ask her something only her aunt would know", { @MainActor in 
          clearScene(); listening();
          try await say2("c8_jessq", [.x(-0.5), .z(-0.4), .gain(1.2)], 900);
          try await say2("c8_alv2", [.x(1.2), .z(-0.8), .gain(1.2)]);
          go("c8truth");
         }),
        Choice("Ask her yourself: “What happened to you?”", to("c8truth")),
      ];
      if (!tapesFound.includes("t1")) { choices.push(Choice("Look through her belongings bag", { @MainActor in 
        clearScene(); listening();
        play("seat", [.x(0.6), .z(-0.6)]);
        try await wait(1500);
        findTape("t1");
        try await tape("t1");
        show("Room 312", "In the plastic bag of her belongings, a cassette from a sheriff's evidence box: “Case file eleven. Walter Hask hasn't been seen since Tuesday. His station is still broadcasting.”\n\nHow did she get this?", choices.slice(0, 2));
       })); }
      show("Room 312", "A small room. A heart monitor beeping. In the bed, a tiny woman with her blanket pulled up to her chin.\n\n“Jessica? Is that you, mija? I've been so cold.”\n\nJess doesn't move. You know what she's thinking. Is it her?", choices);
     }
    scene("c8truth") { @MainActor in 
      listening();
      try await wait(1000);
      try await say2("c8_alv3", [.x(1.2), .z(-0.8), .gain(1.3)], 700);
      try await say2("c8_jess2", [.x(-0.5), .z(-0.4), .gain(1.3)], 600);
      squelch(0, -2); 
      try await wait(300);
      play("c8_nurse2", [.y(2), .z(-1), .phone(true), .gain(1.5), .rate(0.95)]);
      try await wait(len("c8_nurse2") + 600);
      for i in upTo(6) { play("unlock", [.x(Math.cos(i) * 5), .z(Math.sin(i) * 5), .delay(i * 0.25), .gain(1)]); }
      try await wait(2500);
      heartbeat(120);
      show("It's a trap", "It's her. She sang the song. She knew you. And she grips Jess's wrist and whispers:\n\n“It kept me. In the dark. It made me talk to it every night, so it could learn me. It let me go so you would come here.”\n\nJess: “It's a trap. We have to go. Now.”\n\nThe intercom crackles. The nurse's voice, calm, slightly wrong: “Code blue, room three-twelve. All staff... please open your doors.”\n\nUp and down the ward, every door lock clicks open.", [
        Choice("Get her into a wheelchair and run", to("c8stairs")),
      ]);
     }
    scene("c8stairs", true) { 
      landing = 0; monitor(false); heartbeat(120);
      show("The stairwell", "The elevator is dead. You take the stairs, Jess and you carrying Mrs. Alvarez between you, three floors down.\n\nIt's in the stairwell with you, somewhere. Sounds from above are sharp and bright. Sounds from below are muffled and dull. At each landing, listen for where it is, and go the other way: through the door on this floor, or keep going down.", [
        Choice("Start down", stairNext),
      ]);
     }
    scene("c8vent") { @MainActor in 
      listening();
      try await wait(1500);
      play("c8_fakealv", [.x(-2), .y(2), .z(-1), .gain(1.5), .lowpass(2500)]);
      try await wait(len("c8_fakealv") + 600);
      show("A voice in the vents", "From an air vent in the wall, soft and sweet:\n\n“Mija... come back to bed.”\n\nMrs. Alvarez's voice. But Mrs. Alvarez is right here, between you, gripping Jess's hand so hard her knuckles are white.", [
        Choice("Keep going", stairNext),
        Choice("Look into the vent", { die("You lean toward the vent. It's so dark in there.\n\nSomething in the dark leans toward you too.") }),
      ]);
     }
    scene("c8end") { @MainActor in 
      heartbeat(90); hum(0); wind(0.06);
      listening();
      play("dooropen", [.z(-2), .gain(1)]);
      try await wait(2500);
      try await say2("c8_alv4", [.x(0.4), .z(-0.4), .gain(1.2)]);
      markDone(9);
      silenceAll();
      show("End of Chapter Eight", "The fire door bangs open into the cold. The parking lot. Ruiz's car, engine running. You get her into the back seat.\n\nMrs. Alvarez takes your hand in both of hers. Her fingers are like ice.\n\n“Whatever it promised you, it lies. Except about one thing. It never forgets a voice.”", [
        Choice("Play Interlude Two: Ruiz", to("z1")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("z1", true) { @MainActor in 
      silenceAll(); music("m_drone", 0.06, 5); hum(0.03); rain(0.08); heartbeat(0);
      listening();
      try await wait(5000);
      ring(30, 0.8, -0.6);
      try await wait(3000);
      show("Interlude Two: Ruiz", "This time, you're Detective Ruiz.\n\nThree in the morning at the county station. Rain on the windows. You drove Jess, her aunt and the kid back up to the cabin, then came down the mountain to go through the 1987 files one more time.\n\nYour desk phone is ringing.", [
        Choice("Answer it", {  ringStop(); go("z2");  }),
        Choice("Let it ring", { 
          clearScene(); listening();
          after(12000, { show("Interlude Two: Ruiz", "It keeps ringing. Ten times. Twenty. It doesn't stop.", [Choice("Answer it", {  ringStop(); go("z2");  })]) });
         }),
      ]);
     }
    scene("z2") { @MainActor in 
      listening();
      play("unlock", [.x(0.3), .z(-0.3), .gain(0.8)]);
      try await wait(1500);
      try await say2("i2_bro1", [.x(0.2), .z(-0.1), .phone(true), .gain(1.5)], 700);
      try await say2("i2_ruiz1", [.x(0), .z(-0.3), .gain(1.1)], 700);
      try await say2("i2_bro2", [.x(0.2), .z(-0.1), .phone(true), .gain(1.5)]);
      show("Danny", "A warm, tired man's voice: “Hey, Tommy. It's Danny. You sound tired, little brother.”\n\nYou hear yourself say: “Danny? It's three in the morning. How did you get this number?”\n\n“Come up to the cabin, Tommy. Bring the tapes. I miss you.”\n\nYour brother Danny has been missing since October 1987. He was nine years old.", [
        Choice("Ask him: “Where have you been?”", { @MainActor in 
          clearScene(); listening();
          try await wait(2000);
          try await say2("i2_kid", [.x(0.2), .z(-0.1), .phone(true), .gain(1.6)], 800);
          tone([.f(480), .dur(0.6), .gain(0.12), .x(0.2), .z(-0.1)]);
          try await wait(1500);
          go("z3");
         }),
        Choice("Hang up", to("z3")),
      ]);
     }
    scene("z3") { 
      heartbeat(110);
      holdStill("The file room", "You go to the file room and pull the 1987 box. Your brother's photo is clipped to the first page.\n\nDaniel Ruiz, age nine. Missing since October 1987. Last seen talking to someone through his bedroom window.\n\nThen, above you, in the ceiling, the vents start to rattle. You know that sound now.\n\nDon't move. Don't call out.",
        [("Call out: “Danny?”", "“Danny?” you whisper.\n\nFrom the vent, a giggle. Then a little boy's voice, delighted: “Tommy, come play.”")],
        [(3000, { crawl(1.5, 4000) }), (9000, { play("i2_kid", [.x(1.5), .y(2.4), .z(-1), .gain(1.2), .lowpass(2500)]) }), (14000, { crawl(-1.5, 4000) }), (21000, { heartbeat(90) })],
        24000, { go("z4") });
     }
}

func registerStory9() {
    scene("z4") { @MainActor in 
      heartStop();
      listening();
      squelch(0.4, -0.6);
      try await wait(400);
      try await say2("i2_disp", [.x(0.4), .z(-0.6), .phone(true), .gain(1.5)], 1500);
      try await say2("i2_ruiz2", [.x(0), .z(-0.3), .gain(1.1)]);
      markDone(10);
      silenceAll();
      show("End of Interlude Two", "Your radio crackles. The dispatcher, flat and calm: “Unit one, Detective Ruiz. Your brother is waiting for you at the cabin.”\n\nThere's no one on dispatch at three in the morning. You know that. You go anyway.\n\n“Okay, Danny. I'm coming.”\n\nYou take the tapes. And your gun. And you drive up to the cabin, where Jess is waiting.", [
        Choice("Play Chapter Nine: Separated", to("c9")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c9", true) { @MainActor in 
      silenceAll(); music("m_drone", 0.1, 5); wind(0.08); fire(0.3); heartbeat(0);
      listening();
      try await wait(3000);
      engine(0.25); try await wait(3500); engine(0);
      carDoor(1.5);
      gravel(5, [.from(1.5, 0, -5), .to(0.3, 0, -2.2), .gap(0.3), .gain(1)]);
      try await wait(2000);
      play("knock", [.z(-2), .gain(1.6), .rate(1.3)]); play("keys", [.x(0.4), .z(-2.2), .delay(0.3)]);
      try await wait(1500);
      play("lock", [.z(-2)]); play("creak", [.z(-2), .delay(0.5), .rate(1.4)]);
      try await wait(2500);
      heartbeat(110);
      for i in upTo(8) { play("tap" + str((i % 2)), [.x(Math.cos(i * 0.8) * 3), .z(Math.sin(i * 0.8) * 3), .delay(i * 0.15), .gain(1.4)]); }
      try await wait(3000);
      show("Chapter Nine: Separated", "Ruiz arrives at the cabin after midnight, soaking wet, with the box of tapes under his arm. He's white as paper. “Something followed me up the road. No headlights. Just... following.”\n\nThen every window in the cabin is tapped at once. All of them. All around you.\n\nJess grabs your hand. Ruiz shouts: “Back door! Into the trees! Go!”", [
        Choice("Run", to("c9run")),
      ]);
     }
    scene("c9run", true) { @MainActor in 
      fire(0); wind(0.18); heartbeat(140);
      listening();
      play("dooropen", [.z(2), .gain(1), .rate(1.4)]);
      gravel(10, [.from(0, 0, 0), .to(0, 0, -6), .gap(0.22), .gain(1)]);
      try await wait(2500);
      play("glassbang", [.x(1), .z(1), .gain(1.6), .rate(0.6)]); boom();
      try await wait(1200);
      show("Separated", "You run into the dark between the pines, Jess's hand in yours. Branches whip your face. Behind you, glass explodes.\n\nYou trip on a root. You hit the ground hard. And Jess's hand is gone.\n\nYou're alone in the woods.\n\nJess said it once: it can't walk and talk at the same time. When it copies a voice, it stays still. The real Jess is moving. Listen for footsteps with the voice, and go toward that one. Left, ahead, or right.", [
        Choice("Get up and listen", {  woodsStep = 0; woodsStrikes = 0; woodsNext();  }),
      ]);
     }
    scene("c9found") { @MainActor in 
      heartbeat(100);
      listening();
      gravel(4, [.from(-2, 0, -2), .to(-0.4, 0, -0.3), .gap(0.25), .gain(1)]);
      try await wait(1500);
      try await say2("c9_found", [.x(-0.3), .z(-0.2), .gain(1.3)], 900);
      gravel(6, [.from(4, 0, 2), .to(0.8, 0, 0), .gap(0.5), .gain(1), .rate(0.7)]);
      try await wait(3000);
      try await say2("c9_ruiz", [.x(0.8), .z(0), .gain(1.3)]);
      show("Ruiz", "And then she's there, crashing into you in the dark, sobbing. “It's you. It's really you. I heard you calling me. Over and over. From everywhere.”\n\nHeavy, limping footsteps. Ruiz, gasping, blood on his hand. “Go. Both of you. I'll slow it down. If you see my brother... tell Danny I'm sorry.”", [
        Choice("“We're not leaving you.”", {  closeness += 1; go("c9ruiz");  }),
        Choice("Take Jess's hand and run", to("c9ruiz")),
      ]);
     }
    scene("c9ruiz") { @MainActor in 
      listening();
      try await wait(1500);
      gravel(8, [.from(0, 0, 0), .to(0, 0, -6), .gap(0.3), .gain(0.8)]);
      play("glassbang", [.x(2), .z(6), .delay(2), .gain(0.8), .lowpass(1500)]);
      try await wait(9000);
      try await say2("c9_crruiz", [.x(-3), .z(-4), .gain(1.4), .lowpass(4000)], 2500);
      try await say2("c9_mine", [.x(-0.4), .z(-0.3), .gain(1.2)]);
      markDone(11);
      silenceAll();
      show("End of Chapter Nine", "Ruiz shoves you both away. He won't move. So you run.\n\nBehind you, the sounds of a struggle in the dark. Then nothing.\n\nMuch later, from the trees ahead of you, Ruiz's voice, flat and calm: “Danny says hi.”\n\nJess pulls you close. Her whisper is shaking, but her voice is sure. “The old mine. Walter said it rests where it's quiet. That's where we end this.”", [
        Choice("Play Chapter Ten: The Hollow", to("c10")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c10", true) { @MainActor in 
      noiseLvl = 0; room = 0;
      silenceAll(); music("m_drone", 0.05, 6); heartbeat(0); drips(true);
      listening();
      try await wait(4000);
      try await say2("c10_jess1", [.x(-0.3), .z(-0.15), .gain(1.1)]);
      show("Chapter Ten: The Hollow", "The mine entrance is a black mouth in the side of the mountain. Inside, the only sounds are dripping water and your own heart.\n\nJess, barely a breath: “From here on, not a word. Squeeze my hand twice if you need me.”\n\nEverything you do down here makes some noise. Choose carefully. If the noise gets too high, it will wake up.", [
        Choice("Go in", { go("c10room") }),
      ]);
     }
    scene("c10room") { @MainActor in 
      let r = ROOMS[room];
      drips(true);
      var choices = r.opts.map({ (label, n) in (Choice(label, { c10act(n) })) });
      if (room == 2 && !tapesFound.includes("t2")) { choices.push(Choice("Pick up the cassette lying on top of the radios (a little noise)", { @MainActor in 
        noiseLvl += 1; clearScene(); listening();
        play("seat", [.z(-0.5), .gain(0.6)]);
        try await wait(1500);
        findTape("t2");
        try await tape("t2");
        go("c10room");
       })); }
      show(r.title, str(r.text) + "\n\nNoise so far: " + str(noiseLvl) + " out of 8.", choices);
      if (r.voices) {
        ["neighbor", "comeout", "c6_dj2", "c6_girl", "i_p1"].forEachI({ v, i in play(v, [.x(Math.cos(i * 1.3) * 5), .z(-4 + Math.sin(i * 1.3) * 3), .delay(i * 0.8), .gain(0.35), .rate(0.75), .lowpass(1200)]) });
        after(5000, { play("c10_walter", [.x(1.5), .z(-2.5), .gain(0.9), .lowpass(3000)]) });
      }
     }
    scene("c10heart") { @MainActor in 
      drips(true); heartbeat(120);
      listening();
      try await wait(2500);
      for i in upTo(3) { play("breath", [.z(-3), .delay(i * 2), .gain(1), .rate(0.6), .lowpass(2500)]); }
      try await wait(6500);
      try await say2("c10_cr", [.z(-3), .gain(1.3), .rate(0.9)], 2500);
      try await say2("c10_jess2", [.x(-0.3), .z(-0.15), .gain(1.1)]);
      markDone(12);
      drips(false);
      show("End of Chapter Ten", "At the bottom of the mine, a cavern. And in the middle of it, something enormous, breathing slowly. Asleep.\n\nIt murmurs in its sleep, in a voice made of all the others: “You came all this way. To be quiet with me?”\n\nJess's hand is shaking in yours. “It's sleeping. If it's ever going to end, it's now.”", [
        Choice("Play Chapter Eleven: Your Voice", to("c11")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c11", true) { @MainActor in 
      silenceAll(); drips(true); music("m_drone", 0.04, 6); heartbeat(0);
      listening();
      try await wait(3000);
      try await say2("c11_jess1", [.x(-0.3), .z(-0.15), .gain(1.1)]);
      show("Chapter Eleven: Your Voice", "Before you go any closer, Jess pulls you behind a rock and puts her lips to your ear.\n\n“Say something. Anything. Just so I know your voice.”\n\nThe game can use your iPhone's microphone here to record about three seconds of your real voice. It stays on this device. It's never uploaded or saved anywhere, and it's gone when you close the game. If you'd rather not, skip it and a stand-in voice is used.\n\nIf you record: after the beep, whisper something, like “I'm here.”", [
        Choice("Record my voice", { @MainActor in 
          clearScene(); show("", "Recording after the beep.", []);
          do {
            try await wait(1500);
            tone([.f(880), .dur(0.15), .gain(0.2)]);
            try await wait(300);
            try await recordVoice(3200);
            tone([.f(660), .dur(0.15), .gain(0.2)]);
            usedMic = true;
            try await wait(600);
            play("myvoice", [.x(-0.3), .z(-0.2), .gain(1.6), .lowpass(3000)]);
            go("c11split");
          } catch is CancellationError {
            return
          } catch {
            usedMic = false; useStandInVoice();
            show("Your voice", "The microphone isn't available, so the game will use a stand-in voice. That's okay.", [Choice("Continue", to("c11split"))]);
          }
         }),
        Choice("Skip, use a stand-in voice", {  usedMic = false; useStandInVoice(); go("c11split");  }),
      ]);
     }
    scene("c11split") { @MainActor in 
      ensureMyVoice();
      heartbeat(110);
      listening();
      try await wait(2500);
      boom(); for i in upTo(6) { play("gravel" + str((i % 3)), [.x(Math.random() * 4 - 2), .y(2), .z(-1), .delay(i * 0.12), .gain(1.5), .rate(0.6)]); }
      try await wait(3500);
      play("myvoice", [.x(-5), .z(-4), .gain(1.5), .lowpass(3500)]);
      try await wait(len("myvoice") + 1500);
      play("myvoice", [.x(5), .z(-2), .gain(1.4), .lowpass(3500), .rate(0.92)]);
      try await wait(len("myvoice") + 1500);
      try await say2("c11_jess2", [.x(1.2), .z(-1), .gain(1.2)]);
      show("Which one is you", "Rocks crash down between you and Jess. When the dust settles, she's a few feet away in the pitch dark, and she can't see you.\n\nThen, from the far side of the cavern: your voice. " + str((usedMic ? "Your real voice. The one you just whispered to her." : "Your voice.")) + " Then again, from somewhere else.\n\nJess, terrified: “Is that you? You're over there... and you're right here. Which one is you?”", [
        Choice("Call out: “It's me, I'm right here!”", { die("“It's me!” you shout.\n\nAnd from all around the cavern, in your voice, a dozen copies shout it too.") }),
        Choice("Whisper the secret word she traced on your hand", { die("You whisper it. " + secretWord.capitalizedFirst + ".\n\nThe dark whispers it back. Now it knows the word. Now it can be her, and you'll never know.") }),
        Choice("Crawl to her in silence and squeeze her hand twice", to("c11end")),
      ]);
     }
    scene("c11end") { @MainActor in 
      listening();
      gravel(3, [.from(0.5, -0.5, -0.5), .to(1, -0.5, -0.8), .gap(0.6), .gain(0.3)]);
      try await wait(3000);
      try await say2("c11_jess3", [.x(0.8), .z(-0.5), .gain(1.2)], 2000);
      try await say2("c11_cr", [.z(-4), .gain(1.4)], 800);
      playReversed("myvoice", [.x(-3), .z(-3), .gain(1.4), .rate(0.85), .lowpass(3000)]);
      try await wait(len("myvoice") + 600);
      play("myvoice", [.x(3), .z(-3), .gain(1.4), .rate(0.7), .lowpass(2500)]);
      try await wait(len("myvoice") / 0.7 + 1200);
      markDone(13);
      silenceAll(); drips(false);
      show("End of Chapter Eleven", "You find her hand in the dark. One squeeze. Two.\n\nShe breaks down, silently, against your shoulder. “Two squeezes. It's you.”\n\nAnd from the dark, delighted: “Thank you for the voice.”\n\nThen it plays your voice back to you. Backwards. Slowed down. Practicing.", [
        Choice("Play Chapter Twelve: Still Here", to("c12")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c12", true) { @MainActor in 
      c12strikes = 0;
      ensureMyVoice();
      silenceAll(); drips(true); music("m_drone", 0.05, 6); heartbeat(0);
      listening();
      try await wait(3000);
      hum(0.02);
      try await say2("c12_jess1", [.x(-0.3), .z(-0.15), .gain(1.1)]);
      show("Chapter Twelve: Still Here", "The last cavern. Walter Hask's old transmitter is down here, dragged into the mountain forty years ago, still humming. Wired to it, a rusted detonator box. Walter tried to bury it once.\n\nIt's awake now. It's thinner than before. Weaker. Jess was right.\n\n“Walter was right. It's starving. It needs us to talk to it.”\n\nIt's going to try everything. Don't speak. Don't press anything unless you mean it.", [
        Choice("Hold her hand and wait", to("c12starve")),
      ]);
     }
}

func registerStory10() {
    scene("c12starve", true) { 
      heartbeat(115);
      show("Starve it", "Silence. Just hold on.", [
        Choice("Say “I love you” back", { go("c12itwins") }),
        Choice("Whisper to Jess", { die("You whisper her name.\n\nIt feeds. You can hear it get stronger. It says her name back, in your voice, and she turns toward the wrong one.") }),
      ]);
      after(2000, { play("c12_cr1", [.z(-3), .gain(1.4)]) });
      let all = ["hello", "neighbor", "jess_code", "i_r9", "c6_dj2", "c6_girl", "c9_crruiz", "c8_fakealv", "comeout"];
      all.forEachI({ v, i in after(8000 + i * 1800, { play(v, [.x(Math.cos(i) * 4), .z(Math.sin(i) * 4), .gain(1), .rate(0.85 + Math.random() * 0.2), .lowpass(3500)]) }) });
      after(26000, { play("myvoice", [.x(2), .z(-1), .gain(1.4)]) });
      after(30000, { play("c12_crlove", [.x(1.5), .z(-1), .gain(1.3)]) });
      after(30000 + len("c12_crlove") + 3000, { play("c12_jesslove", [.x(-0.3), .z(-0.1), .gain(1.2)]) });
      after(30000 + len("c12_crlove") + len("c12_jesslove") + 3500, { 
        show("Starve it", "It tried every voice it ever stole. It tried yours.\n\nThen, from a few feet away, in Jess's voice, too calm: “I love you. Say it back.”\n\nAnd then, right against your ear, Jess, the real one, crying: “I love you. Don't answer. Just squeeze.”", [
          Choice("Say “I love you” back", { go("c12itwins") }),
          Choice("Squeeze her hand", to("c12choice")),
        ]);
       });
     }
    scene("c12itwins") { @MainActor in 
      silenceAll(); drips(false);
      listening();
      try await wait(2000);
      play("myvoice", [.z(-2), .gain(1.4), .rate(0.9)]);
      try await wait(len("myvoice") + 800);
      play("c11_cr", [.z(-1), .gain(1.5)]);
      try await wait(len("c11_cr") + 2000);
      ring(3, -2.5, 1);
      try await wait(12000);
      play("myvoice", [.x(-2.5), .z(1), .phone(true), .gain(1.6)]);
      try await wait(len("myvoice") + 600);
      play("c5_learning", [.x(-2.5), .z(1), .phone(true), .gain(1.4)]);
      try await wait(len("c5_learning") + 1500);
      markEnding("itwins"); markDone(14);
      show("Ending: It Wins", "You said it back. Of course you did. You love her.\n\nAnd it heard you say it. That was all it ever needed.\n\nMonths later, Jess lives alone in a city far from Elk Ridge. Every night at two in the morning, her phone rings. It's you. It's always you. You tell her you love her. You ask her to open the door.\n\nOne of these nights, she will.", [
        Choice("Try again from the last checkpoint", { go(checkpoint) }),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c12choice") { @MainActor in 
      heartbeat(100);
      listening();
      try await wait(2500);
      try await say2("c12_crdie", [.z(-3), .gain(1.2), .rate(0.9)], 1200);
      let canSilence = closeness >= 4 && toldTruth >= 2;
      var choices = [
        Choice("Light the detonator and run together", { go(closeness >= 3 ? "c12together" : "c12promise") }),
        Choice("Light it, and stay behind to keep it busy while Jess runs", { go("c12promise") }),
      ];
      if (canSilence) { choices.unshift(Choice("Don't blow anything up. Stay with her in the silence, until it's gone", to("c12silence"))); }
      show("The end of it", "You squeeze. She squeezes back. Neither of you says a word.\n\nIt's fading. Its voice is thin, coming apart: “I was... still... here...”\n\nBut it isn't dead. Not yet. Beside you, Walter's detonator. One spark and this whole mountain comes down on it.\n\n" + str((canSilence ? "Or. Jess's hand in yours, steady now. You've been honest from the start, and you've never let go of each other. Maybe silence is enough." : "Jess looks at the detonator. Then at you.")), choices);
     }
    scene("c12together") { @MainActor in 
      listening();
      play("unlock", [.z(-0.5), .gain(1.3)]);
      try await wait(800);
      gravel(16, [.from(0, 0, 0), .to(0, 0, -10), .gap(0.22), .gain(1)]);
      try await wait(4500);
      boom(); boom(); crash();
      try await wait(6000);
      stopAll(); drips(false); music("m_rest", 0.25, 6); birds(true);
      try await wait(3000);
      try await epilogue("together", "Ending: Together", "You light the fuse and you run, hand in hand, up through the dark, and the mountain comes down behind you.\n\nOn the morning news: the old Elk Ridge mine has collapsed. No injuries reported. Ruiz, in a hospital bed with his arm in a cast, grins when he sees you: “Kid. You did it. Danny would've liked you.”\n\nThat night, in a motel room with the window open, Jess lies with her head on your shoulder. “Hey. Listen. Nothing. Just us.”", [
        ("c12_news1", [.x(0.4), .z(-0.8), .phone(true), .gain(1.4)], 1200),
        ("c12_ruiz", [.x(0.6), .z(-0.6), .gain(1.2)], 1500),
        ("c12_jessend", [.x(-0.3), .z(-0.1), .gain(1.2)], 1500),
      ]);
     }
    scene("c12promise") { @MainActor in 
      listening();
      play("unlock", [.z(-0.5), .gain(1.3)]);
      try await wait(1000);
      gravel(10, [.from(-0.5, 0, 0), .to(-1, 0, -10), .gap(0.25), .gain(0.9)]);
      try await wait(2000);
      try await say2("c12_jessalone", [.x(-2), .z(-8), .gain(1.3)], 300);
      play("myvoice", [.z(-2), .gain(1.2)]); play("c12_cr1", [.z(-2.5), .gain(1.2), .delay(1)]);
      try await wait(4000);
      boom(); boom(); crash();
      try await wait(7000);
      stopAll(); drips(false); music("m_rest", 0.18, 6);
      try await wait(3000);
      try await epilogue("promise", "Ending: The Promise", "You stay. You talk to it, out loud, anything, everything, to keep it hungry and close, while Jess runs.\n\n“I'll come back for you! I promise!”\n\nThe mountain comes down.\n\nOn the morning news: the Elk Ridge mine has collapsed. One person is still missing.\n\nJess keeps her promise. She comes back to the rubble every night. She sits in the dark and doesn't say a word. And sometimes, very faintly, from deep under the stones, she hears someone whisper her name.\n\nShe never answers. She doesn't know which one of you it is.", [
        ("c12_news1", [.x(0.4), .z(-0.8), .phone(true), .gain(1.4)], 1500),
      ]);
     }
    scene("c12silence") { @MainActor in 
      heartbeat(90);
      holdStill("Silence", "You don't touch the detonator. You sit down on the cold stone with Jess, her hand in yours, and you give it nothing. Not a word. Not a sound.\n\nThis is the hardest thing you've ever done. Don't press anything.",
        [("Say something, anything, to Jess", "You can't stand it anymore. You whisper her name.\n\nIt was so close to the end. It drinks the sound like water.")],
        [(4000, { play("c12_cr1", [.z(-2.5), .gain(0.9), .rate(0.9)]) }),
         (12000, { play("myvoice", [.z(-2.5), .gain(0.8), .rate(0.8), .lowpass(2000)]) }),
         (20000, { play("c12_crlove", [.z(-2.5), .gain(0.6), .rate(0.85), .lowpass(1500)]) }),
         (30000, { play("c12_crdie", [.z(-2.5), .gain(0.5), .rate(0.7), .lowpass(1000)]) }),
         (38000, {  hum(0); drips(false); heartbeat(60);  }),
         (48000, { heartStop() })],
        60000, { @MainActor in 
          clearScene(); listening();
          music("m_rest", 0.22, 8);
          try await wait(3000);
          birds(true);
          try await epilogue("silence", "Ending: Silence", "Minute by minute, its voice gets thinner. It tries yours, and it's barely a breath. It tries “I love you,” and the words fall apart halfway through.\n\nAnd then there's nothing. Not breathing. Not dripping water. The transmitter's hum stops by itself.\n\nYou walk out of the mine at sunrise without saying a word, and you don't speak until you're all the way down the mountain.\n\nThat night on the radio: for the first time in forty years, the old KROD tower on Elk Ridge has gone dark. Ruiz calls you from his hospital bed. “Kid. You did it. Danny would've liked you.”\n\nJess, beside you, in the quiet: “Hey. Listen. Nothing. Just us.”", [
            ("c12_news2", [.x(0.4), .z(-0.8), .phone(true), .gain(1.4)], 1500),
            ("c12_ruiz", [.x(0.2), .z(-0.1), .phone(true), .gain(1.3)], 1500),
            ("c12_jessend", [.x(-0.3), .z(-0.1), .gain(1.2)], 1500),
          ]);
         });
     }
    scene("c13", true) { @MainActor in 
      silenceAll(); music("m_rest", 0.14, 5); city(0.05); heartbeat(0);
      listening();
      try await wait(2000);
      for i in upTo(3) { play("trunk", [.x(-1 + i), .z(-1.5), .delay(i * 0.9), .gain(0.9), .rate(0.6), .lowpass(1500)]); }
      try await wait(3200);
      play("keys", [.x(-0.5), .z(-0.5)]);
      try await say2("a13_moving", [.x(-0.5), .z(-0.4), .gain(1.2)]);
      show("Chapter Thirteen: After", "Six months later.\n\nA tiny apartment on the third floor, three hundred miles from Elk Ridge. Traffic hums outside. The stairs creak in a normal, boring way. Jess drops the last cardboard box and flops onto the couch, laughing.\n\n“Okay, that's the last box. Welcome home. Our home. That's so weird to say.”", [
        Choice("Set up the smart speaker", to("c13b")),
      ]);
     }
    scene("c13b") { @MainActor in 
      listening();
      try await wait(1500);
      speakerChime(-1.5, -1.5);
      try await wait(800);
      try await say2("a13_asst", [.x(-1.5), .z(-1.5), .phone(true), .gain(1.3)], 900);
      try await say2("a13_lights", [.x(-0.5), .z(-0.4), .gain(1.2)], 300);
      speakerChime(-1.5, -1.5); play("unlock", [.y(2), .z(-1), .gain(0.5)]);
      try await wait(1500);
      show("Turn on the lights", "Jess insisted. “Everybody has one. It plays music and sets timers. It's harmless.”\n\nA cheerful voice from the kitchen counter: “Hi there! I'm all set up. Try saying, turn on the lights.”\n\nJess, laughing: “Turn on the lights.” Click. The lights come on.\n\nIt's the first voice in the apartment that isn't one of yours.", [
        Choice("Make dinner, Ruiz is coming over", to("c13ruiz")),
      ]);
     }
    scene("c13ruiz") { @MainActor in 
      listening();
      for i in upTo(5) { play("plate", [.x(-1.5), .z(-1), .delay(i * 0.6), .gain(0.8), .rate(0.9 + Math.random() * 0.2)]); }
      try await wait(3500);
      play("knock", [.z(-3), .gain(1), .rate(1.2)]);
      try await wait(1500);
      play("creak", [.z(-3), .rate(1.3), .gain(0.8)]);
      try await wait(1500);
      try await say2("a13_ruiz", [.x(0.6), .z(-0.8), .gain(1.2)]);
      show("Ruiz", "Ruiz arrives with a bag of groceries and his arm finally out of the cast. He looks younger. He laughs at Jess's cooking and eats three plates of it anyway.\n\n“You two look good. Better than good. I've been sleeping through the night. First time since I was nine.”", [
        Choice("Hug him", {  closeness += 1; go("c13date");  }),
        Choice("Ask him: “How are you, really?”", to("c13date")),
      ]);
     }
    scene("c13date") { 
      show("Date night", "A Friday night, a few weeks later. Your first real date, the kind normal people have. Jess lets you pick.", [
        Choice("Dance in the kitchen", { try await c13dance("kitchen") }),
        Choice("Walk by the river", { try await c13dance("river") }),
        Choice("Stay in and listen to the rain", { try await c13dance("rain") }),
      ]);
     }
    scene("c13news") { @MainActor in 
      listening();
      try await wait(1500);
      try await say2("a13_news", [.x(1), .z(-2), .gain(1.1), .lowpass(5000)], 600);
      play("unlock", [.x(1), .z(-2)]);
      try await wait(1200);
      show("The news", "A week later, the TV is on in the background while you cook.\n\n“And in Elk Ridge, a strange story. Dozens of residents say they've received voicemails from family members who passed away years ago. The phone company is calling it a glitch.”\n\nJess turns it off. Neither of you says the words Elk Ridge out loud for the rest of the night.", [
        Choice("Go to bed", to("c13night")),
      ]);
     }
    scene("c13night") { @MainActor in 
      music("m_air", 0.06, 4); city(0.03);
      listening();
      try await wait(3000);
      try await say2("a13_call", [.x(-0.25), .z(0.05), .gain(1.1)]);
      show("Pocket dial", "In bed, nearly asleep, Jess murmurs against your shoulder:\n\n“Hey. You called me today, at lunch. You didn't say anything. You just... breathed. Pocket dial?”\n\nYou didn't call her today.", [
        Choice("Check your phone", { @MainActor in 
          clearScene(); listening();
          tone([.f(1200), .dur(0.05), .gain(0.08), .x(0.3), .z(-0.2)]);
          try await wait(1500);
          for i in upTo(2) { play("breath", [.x(0.3), .z(-0.2), .phone(true), .gain(1), .delay(i * 1.4)]); }
          try await wait(4000);
          markDone(15);
          show("End of Chapter Thirteen", "Recent calls. Outgoing call to Jess, 12:14 PM. Four minutes.\n\nYou were at work at 12:14. Your phone was in your desk drawer.\n\nThere's a recording attached. You play it. Four minutes of slow, wet breathing.\n\nIn the kitchen, the smart speaker's light blinks on. Nobody asked it anything.", [
            Choice("Play Chapter Fourteen: The Assistant", to("c14")),
            Choice("Main menu", to("title")),
          ]);
         }),
      ]);
     }
}

func registerStory11() {
    scene("c14", true) { @MainActor in 
      silenceAll(); music("m_drone", 0.08, 5); city(0.04); heartbeat(0);
      ensureMyVoice();
      listening();
      try await wait(2000);
      tone([.f(1200), .dur(0.05), .gain(0.08), .x(0.3), .z(-0.2)]);
      try await wait(600);
      play("myvoice", [.x(0.3), .z(-0.2), .phone(true), .gain(1.4)]);
      try await wait(len("myvoice") + 1500);
      speakerChime(-1.5, -1.5);
      try await say2("a14_twovoice", [.x(-1.5), .z(-1.5), .phone(true), .gain(1.3)], 800);
      try await say2("a14_safe", [.x(-0.4), .z(-0.3), .gain(1.2)]);
      show("Chapter Fourteen: The Assistant", "It gets worse. Jess's phone has three voice messages from you that you never sent. Yours has one from you, too. Your voice, saying nothing you remember saying.\n\nYou don't move out. You're done running. Instead you set up the new smart lock's best feature: “Two-voice security is on. Your front door will only unlock when two registered voices ask at the same time.”\n\nJess, relieved but not quite: “Two voices. It can only ever be one of us at a time. Right?”", [
        Choice("Go to bed", to("c14alert")),
      ]);
     }
    scene("c14alert", true) { @MainActor in 
      music("m_drone", 0.05, 3); city(0.02);
      listening();
      try await wait(7000);
      heartbeat(120);
      emergencyAlert();
      try await wait(5000);
      try await say2("a14_alert", [.x(0.4), .z(-0.3), .phone(true), .gain(1.4)]);
      emergencyAlert();
      try await wait(4500);
      show("Emergency alert", "At 2:11 a.m., both phones scream at once. That harsh, rising, ugly sound. Simulated, part of the game, but your heart doesn't know that.\n\nA flat automated voice: “Emergency alert. This is a statewide alert. Do not open your door for anyone. Do not answer voices you recognize. Unplug all voice-controlled devices. This is not a test.”\n\nThere are four smart speakers in the apartment. In the dark, one of them starts to talk.", [
        Choice("Find them and unplug them", {  hunt = 0; huntStrikes = 0; huntNext();  }),
      ]);
     }
    scene("c14door") { @MainActor in 
      heartbeat(90);
      listening();
      try await wait(4000);
      play("a14_jessunlock", [.z(-3), .gain(1.4), .lowpass(5000)]);
      play("a14_crunlock", [.z(-3), .gain(1.4), .lowpass(5000)]);
      play("myvoice", [.z(-3), .gain(1.2), .lowpass(5000), .rate(0.95)]);
      try await wait(Math.max(len("a14_jessunlock"), len("a14_crunlock")) + 600);
      speakerChime(0, -3);
      try await say2("a14_unlock", [.z(-3), .phone(true), .gain(1.4)], 200);
      play("unlock", [.z(-3), .gain(1.6)]);
      heartbeat(150);
      show("The front door", "All four speakers are dead. Silence. Jess is shaking against you in the dark.\n\nThen, from the front door: two voices, at exactly the same time. Jess's. And yours. “Unlock the front door.”\n\nThe smart lock has its own microphone.\n\n“Two voices confirmed. Unlocking the front door.” Click.", [
        Choice("Run and throw the old manual deadbolt", { @MainActor in 
          clearScene(); listening();
          gravel(4, [.from(0, 0, 0), .to(0, 0, -2.5), .gap(0.2), .gain(0.8)]);
          try await wait(900);
          play("lock", [.z(-3), .gain(1.8)]); play("trunk", [.z(-3), .gain(1.6), .delay(0.3), .rate(0.6)]);
          try await wait(3000);
          try await say2("a14_sang", [.x(-0.3), .z(-0.2), .gain(1.2)]);
          markDone(16);
          silenceAll();
          show("End of Chapter Fourteen", "You slam the deadbolt home a second before the handle turns. Something leans on the door from the outside. Then it stops.\n\nJess, whispering: “It said it with both our voices. At the same time. It sang.”\n\nYou remember the little girl on the hidden tape: “Sometimes it sings. With everybody's voices at once.”\n\nTwo voices was never going to be enough.", [
            Choice("Play Chapter Fifteen: Ruiz's Last Tape", to("c15")),
            Choice("Main menu", to("title")),
          ]);
         }),
        Choice("Grab Jess and hide in the bedroom", { die("You pull Jess into the bedroom and shut the door.\n\nBehind you, the front door swings open. It doesn't need to hurry. The bedroom door has a smart lock too.") }),
      ]);
      after(opts.extraTime ? 16000 : hardOr(10000, 6000), { die("You froze. The front door swings open, and two voices say your name at once.") });
     }
    scene("c15", true) { @MainActor in 
      dannyKept = false;
      silenceAll(); music("m_drone", 0.08, 5); heartbeat(0);
      listening();
      try await wait(2000);
      ring(3, 0.3, -0.3);
      try await wait(9000);
      ringStop();
      try await say2("a15_call", [.x(0.2), .z(-0.1), .phone(true), .gain(1.4)]);
      show("Chapter Fifteen: Ruiz's Last Tape", "The next morning, Ruiz calls. He sounds like he hasn't slept.\n\n“Kid, it's me. Listen. The tapes, the ones from eighty-seven. There's new stuff on them. Your voices. Things you said last week.”", [
        Choice("Drive to Ruiz's house", to("c15b")),
      ]);
     }
    scene("c15b", true) { @MainActor in 
      engine(0.25);
      listening();
      try await wait(5000);
      engine(0); carDoor(-0.9);
      try await wait(2000);
      fire(0.6);
      try await wait(2500);
      try await say2("a15_doors", [.x(0.6), .z(-0.8), .gain(1.3)]);
      burnCount = 0;
      show("The barrel", "Ruiz has a steel barrel burning in his backyard. The box of 1987 tapes sits next to it, and a garbage bag full of old phones, answering machines, voice recorders. Everything in his house that ever held a voice.\n\n“It doesn't live in the mountain anymore. It lives in every recording of a voice. Tapes, phones, voicemail, those speakers. Every copy is a door.”", [
        Choice("Throw the first tape in", burnNext),
      ]);
     }
    scene("c15danny") { @MainActor in 
      listening();
      try await wait(1500);
      try await tape("a15_danny", 1200);
      try await say2("a15_keep", [.x(0.6), .z(-0.8), .gain(1.3)]);
      show("The last tape", "At the bottom of the box, a tape with a child's handwriting on it. Ruiz plays it before he can stop himself. A little boy, singing:\n\n“Twinkle, twinkle, little star... how I wonder what you are...”\n\nRuiz's voice breaks. “That's Danny. The real Danny. My mom taped him singing, the summer before. If I burn it, I never hear him again.”", [
        Choice("Tell him: “Keep it. It's yours, not its.”", {  dannyKept = true; go("c15end");  }),
        Choice("Let Jess talk to him", { @MainActor in 
          clearScene(); listening();
          try await say2("a15_letgo", [.x(-0.5), .z(-0.5), .gain(1.2)], 2500);
          play("trunk", [.x(0.3), .z(-1), .gain(0.8), .rate(0.5), .lowpass(1500)]); fire(1);
          try await wait(4000); fire(0.6);
          dannyKept = false; go("c15end");
         }),
      ]);
     }
    scene("c15end") { @MainActor in 
      listening();
      try await wait(2000);
      try await say2("a15_cr", [.x(0.3), .z(-1), .gain(1.4), .lowpass(4000)]);
      markDone(17); saveStory();
      saveDanny();
      silenceAll();
      show("End of Chapter Fifteen", str((dannyKept ? "Ruiz puts Danny's tape in his shirt pocket, over his heart. He doesn't say thank you. He doesn't have to.\n\n" : "Jess takes his hand. “He was your brother, Tommy. Not its. Let him go.” For a long time, Ruiz just holds the tape. Then he drops it into the fire himself.\n\n")) + "From the flames, the creature's whisper, amused: “You can't burn all of them. You recorded yourselves.”\n\nYour phones. Every voice message you ever sent. It's right.", [
        Choice("Play Chapter Sixteen: Unrecorded", to("c16")),
        Choice("Main menu", to("title")),
      ]);
     }
    scene("c16", true) { @MainActor in 
      ensureMyVoice();
      silenceAll(); music("m_gloom", 0.12, 5); city(0.02); heartbeat(0);
      listening();
      try await wait(2000);
      try await say2("a16_tower", [.x(0.4), .z(-0.4), .phone(true), .gain(1.4)], 900);
      try await say2("a16_plan", [.x(-0.4), .z(-0.3), .gain(1.2)]);
      delIdx = 0;
      show("Chapter Sixteen: Unrecorded", "That night. Ruiz, on speakerphone: “I got the cell tower shut down. One hour of silence. That's all I could buy you.”\n\nJess sits beside you on the floor with both your phones and her laptop.\n\n“Our phones. The cloud. Every voice message we ever sent. We delete everything. Together. Tonight.”\n\nEvery recording you delete, it will play one last time. Don't stop.", [
        Choice("Start deleting", delNext),
      ]);
     }
    scene("c16last", true) { @MainActor in 
      heartbeat(130);
      listening();
      try await wait(2000);
      play("myvoice", [.x(0.3), .z(-0.4), .phone(true), .gain(1.4)]);
      try await wait(len("myvoice") + 900);
      try await say2("a16_who", [.z(-1), .gain(1.3)]);
      show("The last recording", "One recording left. It's on your phone. You know which one.\n\nYour voice. " + str((usedMic ? "Your real voice, the one you whispered in the mine." : "The voice it stole from you in the mine.")) + "\n\nFrom everywhere and nowhere, fading: “Wait. If I'm gone... who will remember you?”\n\n" + str((usedMic ? "If you choose to delete it, the game really will delete your recording now." : "Deleting it here means it's gone for good.")), [
        Choice("Delete my voice", to("c16unrecorded")),
        Choice("Keep it. Just this one.", to("c16echo")),
      ]);
     }
    scene("c16unrecorded") { @MainActor in 
      audio.store("myvoice", nil); audio.store("myvoice_rev", nil); usedMic = false;
      silenceAll(); heartbeat(0);
      listening();
      tone([.f(500), .f2(60), .dur(0.8), .gain(0.15), .x(0.3), .z(-0.4)]);
      try await wait(9000);
      try await say2("a16_say", [.x(-0.3), .z(-0.1), .gain(1.2)]);
      show("Silence", "Deleted.\n\nAnd then: nothing. Not a hum, not a whisper. The kind of silence you've been afraid of for months, except this time it's empty. Really empty.\n\nJess is crying and smiling at the same time. “Say something. Anything. I just want to hear it the real way.”", [
        Choice("Say something to her", { @MainActor in 
          clearScene(); listening();
          try await wait(2500);
          try await say2("a16_there", [.x(-0.3), .z(-0.1), .gain(1.2)], 1500);
          music("m_rest", 0.2, 6); birds(true);
          try await wait(2000);
          try await say2("a16_news", [.x(1), .z(-2), .gain(1.1), .lowpass(5000)], 1200);
          if (!dannyKept) { try await say2("a16_ruizend", [.x(0.4), .z(-0.3), .phone(true), .gain(1.3)], 1500); }
          else { try await wait(3000); play("a15_danny", [.x(0.4), .z(-0.3), .phone(true), .gain(1.2), .rate(0.85), .lowpass(2500)]); try await wait(len("a15_danny") / 0.85 + 1500); }
          markEnding("unrecorded"); markDone(18);
          silenceAll();
          show("Ending: Unrecorded", "You say it out loud, in your own voice, the real way. She laughs through her tears. “There you are.”\n\nA week later, on the news: “In Elk Ridge, those strange voicemails have stopped. Residents say their phones have been quiet all week. Just quiet.”\n\n" + str((dannyKept ? "But two hundred miles away, at 2 a.m., in a shirt pocket in a dark bedroom, an old cassette clicks on by itself. A little boy, singing, slower than he ever sang: “Twinkle, twinkle, little star...”\n\nIt only ever needed one." : "Ruiz calls you a month later. “I don't remember exactly how Danny sounded anymore. I think that's okay. I remember him.”")) + "\n\nThank you for playing Still Here.", [
            Choice("Endings found: " + str(endings.length) + " of " + str(ENDINGS.length), to("endings")),
            Choice("Credits", to("credits")),
            Choice("Main menu", to("title")),
          ]);
         }),
      ]);
     }
    scene("c16echo") { @MainActor in 
      silenceAll(); heartbeat(0);
      listening();
      try await wait(4000);
      music("m_rest", 0.12, 6);
      try await wait(4000);
      play("myvoice", [.x(4), .z(-2), .gain(1.1), .lowpass(3000)]);
      try await wait(len("myvoice") + 1200);
      try await say2("c11_cr", [.x(4), .z(-2), .gain(1.2)], 1500);
      markEnding("echo"); markDone(18);
      silenceAll();
      show("Ending: Echo", "You keep it. Just the one. Your own voice. That can't hurt anyone.\n\nThe voicemails stop. The speakers stay quiet. Months go by. You're happy. Jess is happy.\n\nThen one evening, cooking dinner, you hear yourself laugh in the next room. Jess is sitting right next to you. She heard it too.\n\nFrom the next room, in your voice, delighted: “Thank you for the voice.”\n\nIt only ever needed one.", [
        Choice("Try again from the last checkpoint", { go(checkpoint) }),
        Choice("Main menu", to("title")),
      ]);
     }
}

func registerStory() {
    registerStory1()
    registerStory2()
    registerStory3()
    registerStory4()
    registerStory5()
    registerStory6()
    registerStory7()
    registerStory8()
    registerStory9()
    registerStory10()
    registerStory11()
}
