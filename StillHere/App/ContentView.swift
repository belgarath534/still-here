import SwiftUI
import UIKit

private let red = Color(red: 0.77, green: 0.09, blue: 0.11)
private let ink = Color(red: 0.85, green: 0.82, blue: 0.77)
private let dim = Color(red: 0.54, green: 0.51, blue: 0.47)
private let buttonFill = Color(red: 0.07, green: 0.03, blue: 0.03)
private let buttonEdge = Color(red: 0.35, green: 0.10, blue: 0.10)

private func serif(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font { .custom("Georgia", size: size, relativeTo: style) }

struct ContentView: View {
    @ObservedObject var model: GameModel
    @AccessibilityFocusState private var narrationFocused: Bool
    @AccessibilityFocusState private var pauseFocused: Bool
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 60)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .opacity(model.screen.dark ? 0.35 : 1)
            .animation(.easeInOut(duration: 3), value: model.screen.dark)
            .accessibilityHidden(model.paused)

            if model.screen.mode == .game && !model.paused {
                VStack {
                    HStack {
                        Spacer()
                        Button("Pause") { openPause() }
                            .font(serif(17))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(buttonFill.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(buttonEdge))
                            .accessibilityHint("Freezes the game. You can also double-tap with two fingers.")
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }

            if model.paused { pauseMenu }

            red.opacity(model.flashOn ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .preferredColorScheme(.dark)
        .onChange(of: model.screen.id) { focusNarration() }
        .onChange(of: model.paused) {
            if model.paused { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { pauseFocused = true } }
            else { focusNarration() }
        }
        .onChange(of: phase) {
            // leaving the app (or the lock screen) freezes the game
            if phase != .active { openPause() }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .alert("Content note", isPresented: Binding(get: { model.note != nil }, set: { _ in })) {
            Button("OK") { model.noteDismissed() }
        } message: {
            Text(model.note ?? "")
        }
    }

    private func focusNarration() {
        narrationFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { narrationFocused = true }
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.24, green: 0.03, blue: 0.04).opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        let splash = model.screen.mode == .splash
        return VStack(alignment: splash ? .center : .leading, spacing: 4) {
            Text("STILL HERE")
                .font(serif(splash ? 52 : 38, .largeTitle))
                .kerning(splash ? 12 : 8)
                .foregroundStyle(red)
                .shadow(color: red.opacity(0.5), radius: 16)
            Text("AN AUDIO HORROR GAME")
                .font(serif(14, .caption))
                .kerning(4)
                .foregroundStyle(dim)
        }
        .frame(maxWidth: .infinity, alignment: splash ? .center : .leading)
        .padding(.top, splash ? 120 : 0)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Still Here. An audio horror game.")
        .accessibilityAddTraits(.isHeader)
        // during play, the game title is just noise for VoiceOver
        .accessibilityHidden(model.screen.mode == .game)
    }

    @ViewBuilder private var content: some View {
        let s = model.screen
        let splash = s.mode == .splash
        if !s.title.isEmpty {
            Text(s.title.uppercased())
                .font(serif(18, .headline))
                .kerning(3)
                .foregroundStyle(dim)
                .padding(.bottom, 16)
                .accessibilityLabel(s.title)
                .accessibilityAddTraits(.isHeader)
        }
        Text(s.text.isEmpty ? " " : s.text)
            .font(serif(21))
            .lineSpacing(6)
            .foregroundStyle(splash ? dim : ink)
            .multilineTextAlignment(splash ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: splash ? .center : .leading)
            .accessibilityFocused($narrationFocused)
            .accessibilityAction(.magicTap) { model.togglePause() }
        VStack(spacing: 12) {
            ForEach(Array(s.choices.enumerated()), id: \.offset) { i, c in
                Button { choose(i, screenID: s.id) } label: {
                    Text(c.label)
                        .font(serif(20))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(splash ? .center : .leading)
                        .frame(maxWidth: .infinity, alignment: splash ? .center : .leading)
                        .padding(.horizontal, 18).padding(.vertical, 15)
                        .frame(minHeight: 54)
                        .background(buttonFill, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(s.mode == .menu && i == 0 ? red : buttonEdge, lineWidth: 1))
                }
                .accessibilityAction(.magicTap) { model.togglePause() }
            }
        }
        .padding(.top, 28)
        .id(s.id)
        if s.panel == .settings {
            SettingsPanel()
                .padding(.top, 28)
        }
    }

    private var pauseMenu: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("PAUSED")
                        .font(serif(30, .largeTitle))
                        .kerning(8)
                        .foregroundStyle(red)
                        .accessibilityLabel("Paused")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($pauseFocused)
                        .padding(.bottom, 14)
                    pauseButton("Resume") { closePause() }
                    pauseButton("Restart from the last checkpoint") { closePause(checkpoint ?? "s1") }
                    pauseButton("Quit to the main menu") { closePause("title") }
                    SettingsPanel().padding(.top, 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { closePause() }
        .accessibilityAction(.magicTap) { closePause() }
    }

    private func pauseButton(_ label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(label)
                .font(serif(20))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.vertical, 15)
                .background(buttonFill, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(buttonEdge))
        }
    }
}

/// Volume sliders and switches. Changes are saved straight away.
struct SettingsPanel: View {
    @State private var master = opts.master
    @State private var musicVol = opts.musicVol
    @State private var extraTime = opts.extraTime
    @State private var soft = opts.soft
    @State private var hard = opts.hard
    @State private var haptics = opts.haptics

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            slider("Master volume", $master)
            slider("Music volume", $musicVol)
            toggle("Extra time for timed choices", $extraTime)
            toggle("Quieter jump scares", $soft)
            toggle("Hard mode: less time to react and fewer warnings", $hard)
            toggle("Vibration", $haptics)
        }
        .onChange(of: master) { opts.master = master; audio.setMaster(master); saveOpts() }
        .onChange(of: musicVol) { opts.musicVol = musicVol; audio.setMusicVolume(musicVol); saveOpts() }
        .onChange(of: extraTime) { opts.extraTime = extraTime; saveOpts() }
        .onChange(of: soft) { opts.soft = soft; saveOpts() }
        .onChange(of: hard) { opts.hard = hard; saveOpts() }
        .onChange(of: haptics) { opts.haptics = haptics; saveOpts() }
    }

    private func slider(_ label: String, _ v: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(serif(19)).foregroundStyle(ink).accessibilityHidden(true)
            Slider(value: v, in: 0...1, step: 0.1, onEditingChanged: { editing in if !editing { drip(0) } })
                .tint(red)
                .accessibilityLabel(label)
                .accessibilityValue("\(Int((v.wrappedValue * 100).rounded())) percent")
        }
    }

    private func toggle(_ label: String, _ v: Binding<Bool>) -> some View {
        Toggle(isOn: v) { Text(label).font(serif(19)).foregroundStyle(ink) }
            .tint(red)
    }
}
