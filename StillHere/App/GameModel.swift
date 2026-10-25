import SwiftUI
import UIKit

/// Connects the game to SwiftUI: holds what's on screen, and speaks to VoiceOver.
final class GameModel: ObservableObject, GameView {
    @Published var screen = Screen()
    @Published var paused = false
    @Published var flashOn = false
    @Published var note: String? = nil
    private var noteThen: (() -> Void)? = nil

    /// The last scene that had something to read, shown under "Listen." while you wait.
    @Published var lastScene: String? = nil

    func render(_ s: Screen) {
        let old = screen
        if old.mode == .game, !old.text.isEmpty, old.text != "Listen.", old.text != "Loading…" {
            lastScene = old.title.isEmpty ? old.text : old.title + ". " + old.text
        }
        if s.mode != .game { lastScene = nil }
        screen = s
    }

    func announce(_ msg: String) {
        // queued, so it doesn't cut off whatever VoiceOver is already reading
        let text = NSAttributedString(string: msg, attributes: [.accessibilitySpeechQueueAnnouncement: true])
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    func flash() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        flashOn = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 1.4)) { self.flashOn = false }
        }
    }

    func contentNote(_ msg: String, then: @escaping () -> Void) {
        noteThen = then
        note = msg
    }
    func noteDismissed() {
        note = nil
        let t = noteThen
        noteThen = nil
        t?()
    }

    func pauseChanged(_ p: Bool) { paused = p }

    func togglePause() {
        if paused { closePause() } else { openPause() }
    }
}
