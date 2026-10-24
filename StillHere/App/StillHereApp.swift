import SwiftUI

@main
struct StillHereApp: App {
    @StateObject private var model: GameModel

    init() {
        let m = GameModel()
        _model = StateObject(wrappedValue: m)
        view = m
        audio = AVBackend()
        startGame()
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-shot"), i + 1 < args.count { screenshotScene(args[i + 1]) }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}

/// For App Store screenshots: `-shot NAME` opens a scene straight away.
private func screenshotScene(_ name: String) {
    checked = true
    switch name {
    case "title": go("title")
    case "knock": go("s1b")
    case "door": go("s7")
    case "radio": go("c7tune")
    case "endings":
        endings = ["alone", "escape", "together", "silence"]
        go("endings")
    case "pause":
        go("s4")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { openPause() }
    default: break
    }
}
