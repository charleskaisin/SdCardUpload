import AppKit
import SwiftUI

private let electricCyan = Color(red: 0.05, green: 0.84, blue: 1.0)

struct ContentView: View {
    @ObservedObject var controller: CarteController
    @State private var orbitIsTurning = false
    @State private var pulseIsGrowing = false
    @State private var ambientIsFloating = false
    @State private var trailsAreMoving = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .fill(backgroundGradient)
                .frame(width: 576, height: 656)
                .overlay(
                    RoundedRectangle(cornerRadius: 64, style: .continuous)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [electricCyan, .purple, .pink, .orange, electricCyan]),
                                center: .center
                            ),
                            lineWidth: 6
                        )
                        .padding(4)
                )
                .shadow(color: phaseColor.opacity(0.42), radius: 28, x: 0, y: 12)

            playfulGlow

            if controller.phase == .working {
                WorkingEnergyField()
                    .frame(width: 576, height: 656)
                    .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
            }

            if controller.needsAccessHelp {
                permissionGate
            } else {
                VStack(spacing: 12) {
                    videoPill
                    missionOrbit
                    actionArea
                }
                .frame(width: 510)
                .offset(y: 19)
            }

            topControls

            if controller.phase == .success {
                CelebrationShow()
                    .frame(width: 576, height: 656)
                    .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
            }
        }
        .frame(width: 640, height: 692)
        .background(WindowConfigurator())
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbitIsTurning = true
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulseIsGrowing = true
            }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                ambientIsFloating = true
            }
            withAnimation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true)) {
                trailsAreMoving = true
            }
        }
    }

    private var topControls: some View {
        HStack(spacing: 9) {
            Button(action: controller.toggleSound) {
                Image(systemName: controller.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .buttonStyle(QuitButtonStyle())
            .accessibilityLabel(controller.soundEnabled ? "Désactiver les sons" : "Activer les sons")
            .help(controller.soundEnabled ? "Couper les sons" : "Activer les sons")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(QuitButtonStyle())
            .accessibilityLabel("Quitter")
            .help("Quitter")
        }
        .offset(x: 208, y: -278)
    }

    private var permissionGate: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 148, height: 148)
                Circle()
                    .stroke(Color.orange.opacity(pulseIsGrowing ? 0.75 : 0.25), lineWidth: 4)
                    .frame(width: pulseIsGrowing ? 148 : 122, height: pulseIsGrowing ? 148 : 122)
                    .shadow(color: .orange.opacity(0.55), radius: 18)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 58, weight: .black))
                    .foregroundColor(.orange)
                    .scaleEffect(pulseIsGrowing ? 1.06 : 0.96)
            }

            VStack(spacing: 8) {
                Text("Une autorisation et c’est parti !")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Carte Claire doit pouvoir effacer les petits fichiers invisibles créés par macOS.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(width: 390)
            }

            VStack(alignment: .leading, spacing: 10) {
                permissionStep("1", "Ouvrez les réglages avec le bouton ci-dessous")
                permissionStep("2", "Activez Carte Claire dans la liste")
                permissionStep("3", "Quittez puis rouvrez l’app")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(width: 462)
            .background(Color.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.14), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Button(action: controller.openFullDiskAccessSettings) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                    Text("Ouvrir les réglages")
                }
            }
            .font(.system(size: 17, weight: .black, design: .rounded))
            .buttonStyle(FixedGlowButtonStyle(color: .orange, width: 462, height: 66))

            Text("Cette étape n’est demandée qu’une fois sur ce Mac.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(electricCyan.opacity(0.88))
        }
        .frame(width: 510)
        .offset(y: 16)
    }

    private func permissionStep(_ number: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.08, green: 0.09, blue: 0.18))
                .frame(width: 25, height: 25)
                .background(Color.orange)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
        }
    }

    private var backgroundGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 0.20, green: 0.15, blue: 0.48),
                Color(red: 0.08, green: 0.10, blue: 0.25),
                Color(red: 0.04, green: 0.05, blue: 0.13)
            ]),
            center: .topLeading,
            startRadius: 25,
            endRadius: 700
        )
    }

    private var playfulGlow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.16), Color.clear, electricCyan.opacity(0.10)],
                        startPoint: ambientIsFloating ? .topTrailing : .topLeading,
                        endPoint: ambientIsFloating ? .bottomLeading : .bottomTrailing
                    )
                )
                .opacity(ambientIsFloating ? 1 : 0.62)

            Ellipse()
                .trim(from: 0.04, to: 0.68)
                .stroke(
                    LinearGradient(colors: [electricCyan.opacity(0.05), electricCyan.opacity(0.74), Color.blue.opacity(0.05)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 650, height: 290)
                .rotationEffect(.degrees(trailsAreMoving ? -8 : -18))
                .offset(x: trailsAreMoving ? 28 : -18, y: trailsAreMoving ? 72 : 34)

            Ellipse()
                .trim(from: 0.44, to: 0.96)
                .stroke(
                    LinearGradient(colors: [Color.pink.opacity(0.04), Color.pink.opacity(0.78), Color.purple.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 620, height: 270)
                .rotationEffect(.degrees(trailsAreMoving ? 190 : 202))
                .offset(x: trailsAreMoving ? -24 : 22, y: trailsAreMoving ? -62 : -24)

            ForEach(0..<14) { index in
                Image(systemName: index % 4 == 0 ? "sparkle" : "circle.fill")
                    .font(.system(size: CGFloat(index % 4 == 0 ? 10 : 3 + index % 3), weight: .bold))
                    .foregroundColor([electricCyan, Color.pink, Color.purple][index % 3].opacity(0.48))
                    .scaleEffect(ambientIsFloating ? 1.18 : 0.72)
                    .offset(
                        x: CGFloat((index * 97) % 500) - 250,
                        y: CGFloat((index * 131) % 650) - 325 + (ambientIsFloating ? -10 : 10)
                    )
            }
        }
        .frame(width: 576, height: 656)
        .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var videoPill: some View {
        HStack(spacing: 11) {
            Image(systemName: "film.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 38)

            Text(controller.videoURL?.lastPathComponent ?? "Choisissez une vidéo")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Button("Changer", action: controller.chooseVideo)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .buttonStyle(GlowCapsuleButtonStyle(color: .purple, compact: true))
                .disabled(controller.phase == .working)
        }
        .padding(.horizontal, 15)
        .frame(width: 482, height: 64)
        .background(Color.white.opacity(0.09))
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var missionOrbit: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius: CGFloat = 158

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [3, 10]))
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(orbitIsTurning ? 360 : 0))

                centralStatus
                    .position(center)

                ForEach(WorkflowStep.allCases, id: \.rawValue) { step in
                    let angle = Angle.degrees(-90 + Double(step.rawValue) * 60)
                    OrbitStep(
                        step: step,
                        currentStep: controller.currentStep,
                        isWorking: controller.phase == .working,
                        phaseColor: phaseColor
                    )
                    .position(
                        x: center.x + cos(CGFloat(angle.radians)) * radius,
                        y: center.y + sin(CGFloat(angle.radians)) * radius
                    )
                }
            }
        }
        .frame(width: 410, height: 382)
    }

    private var centralStatus: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.09))
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .frame(width: 244, height: 244)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    LinearGradient(colors: [phaseColor, electricCyan, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 244, height: 244)
                .animation(.easeInOut(duration: 0.35), value: ringProgress)

            if controller.phase == .working && controller.progress == nil {
                Circle()
                    .trim(from: 0.03, to: 0.22)
                    .stroke(electricCyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(orbitIsTurning ? 270 : -90))
                    .frame(width: 244, height: 244)
            }

            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(Color(red: 0.06, green: 0.08, blue: 0.18))
                        .frame(width: 82, height: 104)
                        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(phaseColor, lineWidth: 4))
                        .shadow(color: phaseColor.opacity(0.35), radius: 12)

                    Image(systemName: cardSymbol)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(phaseColor)
                        .scaleEffect(pulseIsGrowing && controller.phase == .working ? 1.08 : 0.96)
                }
                .offset(y: pulseIsGrowing && controller.phase != .failure ? -2 : 2)

                Text(controller.statusTitle)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(controller.statusDetail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: 194)

                if controller.phase == .working, let progress = controller.progress {
                    Text("\(Int(progress * 100)) %")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(electricCyan)
                }

                if let card = controller.card {
                    Text("\(card.name)  •  \(card.sizeText)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(electricCyan.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .frame(width: 204)
        }
        .frame(width: 252, height: 252)
    }

    private var actionArea: some View {
        VStack(spacing: 7) {
            Button(action: controller.askToPrepare) {
                HStack(spacing: 9) {
                    Image(systemName: controller.phase == .success ? "sparkles" : "play.fill")
                    Text(primaryButtonTitle)
                }
            }
            .font(.system(size: 17, weight: .black, design: .rounded))
            .buttonStyle(FixedGlowButtonStyle(color: .pink, width: 482, height: 64))
            .disabled(!controller.canPrepare)
            .scaleEffect(controller.phase == .ready && pulseIsGrowing ? 1.018 : 1)

            if controller.canEject && controller.phase != .working {
                Button("Éjecter sans préparer", action: controller.ejectCurrentCard)
                    .buttonStyle(OrbitLinkButtonStyle(color: electricCyan))
            }
        }
        .frame(height: 86)
    }

    private var primaryButtonTitle: String {
        switch controller.phase {
        case .waiting: return "En attente…"
        case .ready: return "GO !"
        case .working: return "C’est parti…"
        case .success: return "Carte suivante !"
        case .failure: return controller.card == nil ? "Nouvelle carte" : "Réessayer"
        }
    }

    private var ringProgress: CGFloat {
        if controller.phase == .success { return 1 }
        if controller.phase == .working, let progress = controller.progress {
            return max(0.015, CGFloat(progress))
        }
        return controller.phase == .ready ? 0.025 : 0
    }

    private var phaseColor: Color {
        switch controller.phase {
        case .waiting: return .orange
        case .ready: return electricCyan
        case .working: return .purple
        case .success: return .green
        case .failure: return .pink
        }
    }

    private var cardSymbol: String {
        switch controller.phase {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        case .working: return "sparkles"
        case .ready: return "play.fill"
        case .waiting: return "arrow.down"
        }
    }

}

private struct OrbitStep: View {
    let step: WorkflowStep
    let currentStep: Int
    let isWorking: Bool
    let phaseColor: Color
    @State private var isBouncing = false

    private var completed: Bool { step.rawValue < currentStep }
    private var active: Bool { step.rawValue == currentStep && isWorking }

    var body: some View {
        ZStack {
            Circle()
                .fill(completed ? Color.green : (active ? phaseColor : Color.white.opacity(0.11)))
                .frame(width: 46, height: 46)
                .overlay(Circle().stroke(active ? Color.white.opacity(0.8) : Color.white.opacity(0.10), lineWidth: 1.5))
                .shadow(color: active ? phaseColor.opacity(0.70) : .clear, radius: 11)

            Image(systemName: completed ? "checkmark" : step.symbol)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(completed || active ? .white : .white.opacity(0.52))
        }
        .frame(width: 54, height: 54)
        .scaleEffect(active && isBouncing ? 1.12 : 1)
        .offset(y: active && isBouncing ? -3 : 0)
        .help(step.title)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isBouncing = true
            }
        }
    }
}

private struct QuitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.65 : 0.9))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.13))
            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
    }
}

private struct FixedGlowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let color: Color
    let width: CGFloat
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(width: width, height: height)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [color, Color.purple, electricCyan.opacity(0.86)]
                        : [Color.gray.opacity(0.54), Color.gray.opacity(0.34)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(Capsule().stroke(Color.white.opacity(isEnabled ? 0.20 : 0.10), lineWidth: 1))
            .clipShape(Capsule())
            .shadow(color: isEnabled ? color.opacity(configuration.isPressed ? 0.25 : 0.48) : .clear, radius: 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : (isEnabled ? 1 : 0.64))
    }
}

private struct GlowCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let color: Color
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 15 : 22)
            .padding(.vertical, compact ? 7 : 12)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [color, color.opacity(0.68), .purple]
                        : [Color.gray.opacity(0.55), Color.gray.opacity(0.38)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(
                color: isEnabled ? color.opacity(configuration.isPressed ? 0.25 : 0.5) : .clear,
                radius: configuration.isPressed ? 4 : 12
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : (isEnabled ? 1 : 0.64))
    }
}

private struct OrbitLinkButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(color.opacity(configuration.isPressed ? 0.6 : 1))
    }
}

private struct WorkingEnergyField: View {
    private let colors: [Color] = [.pink, .purple, electricCyan, .orange, .yellow]
    @State private var particlesAreFlying = false
    @State private var ringsAreExpanding = false
    @State private var vortexIsTurning = false

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 + 22)

            ZStack {
                ForEach(0..<4) { index in
                    Circle()
                        .stroke(colors[index].opacity(ringsAreExpanding ? 0.02 : 0.42), lineWidth: CGFloat(2 + index))
                        .frame(width: CGFloat(130 + index * 34), height: CGFloat(130 + index * 34))
                        .scaleEffect(ringsAreExpanding ? 2.15 : 0.62)
                        .position(center)
                        .animation(
                            .easeOut(duration: 1.35 + Double(index) * 0.16)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.20),
                            value: ringsAreExpanding
                        )
                }

                ForEach(0..<56) { index in
                    let angle = Double(index) * 137.5 * .pi / 180
                    let distance = CGFloat(105 + (index * 29) % 255)
                    let startDistance = CGFloat(25 + (index * 7) % 42)
                    let size = CGFloat(3 + index % 6)

                    Capsule()
                        .fill(colors[index % colors.count])
                        .frame(width: index % 4 == 0 ? size * 3.2 : size, height: size)
                        .shadow(color: colors[index % colors.count].opacity(0.8), radius: 5)
                        .rotationEffect(.radians(angle))
                        .position(
                            x: center.x + cos(angle) * (particlesAreFlying ? distance : startDistance),
                            y: center.y + sin(angle) * (particlesAreFlying ? distance : startDistance)
                        )
                        .opacity(particlesAreFlying ? 0.02 : 0.92)
                        .animation(
                            .easeOut(duration: 0.75 + Double(index % 9) * 0.09)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index % 13) * 0.055),
                            value: particlesAreFlying
                        )
                }

                ForEach(0..<3) { index in
                    Ellipse()
                        .trim(from: 0.05, to: 0.38)
                        .stroke(
                            colors[index].opacity(0.55),
                            style: StrokeStyle(lineWidth: CGFloat(3 + index), lineCap: .round)
                        )
                        .frame(width: CGFloat(390 + index * 75), height: CGFloat(170 + index * 28))
                        .rotationEffect(.degrees(vortexIsTurning ? Double(360 + index * 55) : Double(index * 55)))
                        .position(center)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                vortexIsTurning = true
            }
            particlesAreFlying = true
            ringsAreExpanding = true
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CelebrationShow: View {
    private let colors: [Color] = [.pink, .purple, electricCyan, .green, .orange, .yellow]
    @State private var isCelebrating = false
    @State private var fireworkIsBlooming = false

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(colors[(index + 2) % colors.count].opacity(fireworkIsBlooming ? 0.01 : 0.72), lineWidth: CGFloat(4 - index))
                        .frame(width: CGFloat(80 + index * 26), height: CGFloat(80 + index * 26))
                        .scaleEffect(fireworkIsBlooming ? 3.6 : 0.35)
                        .position(center)
                        .animation(
                            .easeOut(duration: 1.2 + Double(index) * 0.18)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.16),
                            value: fireworkIsBlooming
                        )
                }

                ForEach(0..<72) { index in
                    let angle = Double(index) * 47.0 * .pi / 180
                    let radius = CGFloat(90 + (index * 37) % 305)
                    let width = CGFloat(4 + index % 5)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[index % colors.count])
                        .frame(width: index % 3 == 0 ? width * 2.5 : width, height: CGFloat(7 + index % 8))
                        .shadow(color: colors[index % colors.count].opacity(0.8), radius: 4)
                        .rotationEffect(.degrees(isCelebrating ? Double(index * 125) : Double(index * 17)))
                        .position(
                            x: center.x + cos(angle) * (isCelebrating ? radius : 35),
                            y: center.y + sin(angle) * (isCelebrating ? radius : 35)
                        )
                        .opacity(isCelebrating ? 0.02 : 0.95)
                        .animation(
                            .easeOut(duration: 0.9 + Double(index % 8) * 0.12)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index % 17) * 0.045),
                            value: isCelebrating
                        )
                }
            }
        }
        .onAppear {
            isCelebrating = true
            fireworkIsBlooming = true
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
