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
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
