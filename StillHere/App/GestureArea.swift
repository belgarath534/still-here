import SwiftUI
import UIKit

/// The Last Stand fight area. With VoiceOver on, it asks for direct touch, so swipes and taps
/// reach the game instead of moving VoiceOver around.
struct GestureArea: UIViewRepresentable {
    let label: String
    let onGesture: (ZGesture) -> Void
    let onPause: () -> Void

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.isAccessibilityElement = true
        v.accessibilityTraits = [.allowsDirectInteraction]
        // no hint: VoiceOver would read it again at every wave
        v.backgroundColor = .clear
        let c = context.coordinator
        for (dir, touches) in [(UISwipeGestureRecognizer.Direction.left, 1), (.right, 1), (.up, 1), (.down, 1), (.down, 2)] {
            let s = UISwipeGestureRecognizer(target: c, action: #selector(Coordinator.swiped(_:)))
            s.direction = dir
            s.numberOfTouchesRequired = touches
            v.addGestureRecognizer(s)
        }
        let pause = UITapGestureRecognizer(target: c, action: #selector(Coordinator.pause))
        pause.numberOfTouchesRequired = 2
        pause.numberOfTapsRequired = 2
        v.addGestureRecognizer(pause)
        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.tapped))
        tap.numberOfTouchesRequired = 1
        v.addGestureRecognizer(tap)
        v.onMagicTap = { c.parent.onPause() }
        return v
    }

    func updateUIView(_ v: TouchView, context: Context) {
        context.coordinator.parent = self
        v.accessibilityLabel = label
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: GestureArea
        init(_ p: GestureArea) { parent = p }
        @objc func swiped(_ s: UISwipeGestureRecognizer) {
            switch s.direction {
            case .left: parent.onGesture(.turnLeft)
            case .right: parent.onGesture(.turnRight)
            case .up: parent.onGesture(.status)
            default: parent.onGesture(.reload)
            }
        }
        @objc func tapped() { parent.onGesture(.shoot) }
        @objc func pause() { parent.onPause() }
    }

    final class TouchView: UIView {
        var onMagicTap: (() -> Void)?
        override func accessibilityPerformMagicTap() -> Bool { onMagicTap?(); return true }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.window != nil else { return }
                UIAccessibility.post(notification: .screenChanged, argument: self)
            }
        }
    }
}
