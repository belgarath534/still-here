import SwiftUI
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
