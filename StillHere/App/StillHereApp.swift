import SwiftUI
import AVFoundation
import UIKit

@main
struct StillHereApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: GameModel

    init() {
        let m = GameModel()
        _model = StateObject(wrappedValue: m)
        view = m
        audio = AVBackend()
        startGame()
        onFeedback = openFeedbackEmail
        onSpeak = { text, urgent in GameSpeech.shared.say(text, urgent: urgent) }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-shot"), i + 1 < args.count { screenshotScene(args[i + 1]) }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}

/// Upright everywhere on iPhone, except the Last Stand fight, which turns sideways.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var mask: UIInterfaceOrientationMask = UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { AppDelegate.mask }

    static func sideways(_ on: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let want: UIInterfaceOrientationMask = on ? .landscape : .portrait
        guard want != mask else { return }
        mask = want
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: on ? .landscape : .portrait)) { _ in }
        }
    }
}

/// Last Stand's "iPhone's own voice": the phone's speech, so the game can talk while VoiceOver is muted.
final class GameSpeech {
    static let shared = GameSpeech()
    private let synth = AVSpeechSynthesizer()
    func say(_ text: String, urgent: Bool) {
        if urgent { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode().hasPrefix("en") ? AVSpeechSynthesisVoice.currentLanguageCode() : "en-US")
        u.rate = min(AVSpeechUtteranceDefaultSpeechRate * 1.15, AVSpeechUtteranceMaximumSpeechRate)
        u.volume = 1
        synth.speak(u)
    }
}

/// A new email to us, with the app and iOS version filled in. Without a mail app, the address is copied instead.
@MainActor func openFeedbackEmail() {
    let app = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
    var c = URLComponents()
    c.scheme = "mailto"
    c.path = FEEDBACK_EMAIL
    c.queryItems = [
        URLQueryItem(name: "subject", value: "Still Here feedback"),
        URLQueryItem(name: "body", value: "\n\n\nStill Here \(app) (\(build)), \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"),
    ]
    // no canOpenURL check: iOS answers "no" for mailto unless the app declares it, so just try
    guard let url = c.url else { copyFeedbackAddress(); return }
    UIApplication.shared.open(url) { ok in if !ok { Task { @MainActor in copyFeedbackAddress() } } }
}
@MainActor private func copyFeedbackAddress() {
    UIPasteboard.general.string = FEEDBACK_EMAIL
    say("No mail app found. The address " + FEEDBACK_EMAIL + " is copied, so you can paste it into any email app.")
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
