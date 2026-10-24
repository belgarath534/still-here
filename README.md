# Still Here

An audio horror game made for VoiceOver and headphones. Sixteen chapters, two interludes and ten endings, told through 3D sound.

## What's in here

- `StillHere/` – the native iPhone app (SwiftUI, AVAudioEngine 3D sound, haptics).
  - `Core/` – the game itself: story, scenes, timers and sound logic. Plain Swift, so it also builds on Linux and macOS for testing.
  - `App/` – iPhone-only parts: screens, VoiceOver, the AVAudioEngine sound system, the microphone.
  - `Audio/` – voices, music and sound effects.
- `Tests/StillHereSim/` – plays every chapter and ending automatically, much faster than real time. Run `swift run StillHereSim`.
- `web/` – the original web version (the one on Netlify).
- `tools/` – the scripts that converted the web version's story to Swift.

## Building

- **GitHub Actions** (`.github/workflows/ios-check.yml`) play-tests the story and builds the app on every push.
- **Codemagic** (`codemagic.yaml`): "Still Here check" does the same; "Still Here TestFlight" signs and uploads to App Store Connect. Bundle ID: `com.stillhere.horror`.

## Credits

Music by Kevin MacLeod (incompetech.com), CC BY 4.0. Voices made with ElevenLabs. Sound effects from Kenney (CC0), wuxiascrub on OpenGameArt (CC0) and Piotrek Zyla (public domain). Full credits are in the game.
