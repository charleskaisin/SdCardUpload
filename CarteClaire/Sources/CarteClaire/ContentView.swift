import AppKit
import SwiftUI

private let electricCyan = Color(red: 0.05, green: 0.84, blue: 1.0)

struct ContentView: View {
    @ObservedObject var controller: CarteController
    @State private var orbitIsTurning = false
    @State private var pulseIsGrowing = false

    var body: some View {
        ZStack {
            SDCardWindowShape()
                .fill(backgroundGradient)
                .frame(width: 640, height: 700)
                .overlay(
                    SDCardWindowShape()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [electricCyan, .purple, .pink, .orange, electricCyan]),
                                center: .center
                            ),
                            lineWidth: 5
                        )
                        .padding(4)
                )
                .shadow(color: phaseColor.opacity(0.42), radius: 28, x: 0, y: 12)

            decorativeCardLines

            VStack(spacing: 8) {
                contactPins
                header
                videoPill
                missionOrbit
                actionArea
                footer
            }
            .frame(width: 590)

            if controller.phase == .success {
                CelebrationDots()
                    .clipShape(SDCardWindowShape())
                    .frame(width: 640, height: 700)
            }
        }
        .frame(width: 720, height: 720)
        .background(WindowConfigurator())
        .alert(isPresented: $controller.showingConfirmation) {
            Alert(
                title: Text("Vider complètement la carte CK ?"),
                message: Text("Tous ses fichiers, y compris les éléments invisibles et sa corbeille, seront définitivement supprimés. La carte ne sera pas reformatée."),
                primaryButton: .destructive(Text("Vider et préparer"), action: controller.prepareConfirmed),
                secondaryButton: .cancel(Text("Annuler"))
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbitIsTurning = true
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulseIsGrowing = true
            }
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

    private var decorativeCardLines: some View {
        ZStack {
            SDCardWindowShape()
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 12]))
                .frame(width: 606, height: 666)

            VStack(spacing: 7) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill([electricCyan, Color.purple, Color.pink][index].opacity(0.10))
                        .frame(width: CGFloat(290 - index * 38), height: 2)
                }
            }
            .offset(y: 285)
        }
        .allowsHitTesting(false)
    }

    private var contactPins: some View {
        HStack(spacing: 7) {
            ForEach(0..<7) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange.opacity(0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: index == 0 || index == 6 ? 26 : 34, height: 25)
                    .shadow(color: .orange.opacity(0.28), radius: 5)
            }
        }
        .frame(width: 420, height: 31)
        .padding(.leading, 72)
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [electricCyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sdcard.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Carte Claire")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("UNE CARTE • UNE VIDÉO • GO !")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(electricCyan.opacity(0.9))
                }
            }

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quitter", systemImage: "xmark")
            }
            .buttonStyle(QuitButtonStyle())
        }
        .frame(width: 510, height: 52)
    }

    private var videoPill: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.24))
                    .frame(width: 38, height: 38)
                Image(systemName: "film.fill")
                    .foregroundColor(.pink)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("VIDÉO À EMBARQUER")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundColor(.white.opacity(0.58))
                Text(controller.videoURL?.lastPathComponent ?? "Choisissez une vidéo")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Button("Changer", action: controller.chooseVideo)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .buttonStyle(GlowCapsuleButtonStyle(color: .purple, compact: true))
                .disabled(controller.phase == .working)
        }
        .padding(.horizontal, 15)
        .frame(width: 510, height: 58)
        .background(Color.white.opacity(0.09))
        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var missionOrbit: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius: CGFloat = 151

            ZStack {
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
        .frame(width: 390, height: 350)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.06, green: 0.08, blue: 0.18))
                        .frame(width: 64, height: 76)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(phaseColor, lineWidth: 3))

                    Image(systemName: cardSymbol)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(phaseColor)
                        .scaleEffect(pulseIsGrowing && controller.phase == .working ? 1.08 : 0.96)
                }

                Text(controller.statusTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(controller.statusDetail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: 190)

                if let card = controller.card {
                    Text("\(card.name)  •  \(card.sizeText)  •  \(shortFileSystem(card.fileSystem))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
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
                    Text(controller.primaryButtonTitle)
                }
                .frame(width: 390)
            }
            .font(.system(size: 15, weight: .black, design: .rounded))
            .buttonStyle(GlowCapsuleButtonStyle(color: .pink, compact: false))
            .disabled(!controller.canPrepare)

            if controller.needsAccessHelp {
                Button(action: controller.openAccessSettings) {
                    Label("Autoriser l’accès aux cartes…", systemImage: "gearshape.fill")
                }
                .buttonStyle(OrbitLinkButtonStyle(color: .orange))
            } else if controller.canEject && controller.phase != .working {
                Button("Éjecter sans préparer", action: controller.ejectCurrentCard)
                    .buttonStyle(OrbitLinkButtonStyle(color: electricCyan))
            } else {
                Text(controller.phase == .success
                     ? "Retirez-la : la prochaine carte sera détectée automatiquement ✨"
                     : "Aucun formatage • La corbeille du Mac reste intacte")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.54))
            }
        }
        .frame(height: 72)
    }

    private var footer: some View {
        Text("CARTE CLAIRE 4.0")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(1.5)
            .foregroundColor(.white.opacity(0.25))
            .frame(height: 12)
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

    private func shortFileSystem(_ value: String) -> String {
        if value.localizedCaseInsensitiveContains("FAT32") { return "FAT32" }
        if value.localizedCaseInsensitiveContains("ExFAT") { return "ExFAT" }
        return value
    }
}

private struct OrbitStep: View {
    let step: WorkflowStep
    let currentStep: Int
    let isWorking: Bool
    let phaseColor: Color

    private var completed: Bool { step.rawValue < currentStep }
    private var active: Bool { step.rawValue == currentStep && isWorking }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(completed ? Color.green : (active ? phaseColor : Color.white.opacity(0.11)))
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(active ? Color.white.opacity(0.8) : Color.white.opacity(0.10), lineWidth: 1.5))
                    .shadow(color: active ? phaseColor.opacity(0.65) : .clear, radius: 9)

                Image(systemName: completed ? "checkmark" : step.symbol)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(completed || active ? .white : .white.opacity(0.52))
            }

            Text(step.title)
                .font(.system(size: 9, weight: active ? .black : .bold, design: .rounded))
                .foregroundColor(active ? .white : .white.opacity(0.55))
        }
        .frame(width: 72, height: 62)
    }
}

private struct SDCardWindowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 26
        let cut: CGFloat = min(118, rect.width * 0.20)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + cut + 10, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut + 10))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 6, y: rect.minY + cut - 4),
            control: CGPoint(x: rect.minX, y: rect.minY + cut + 2)
        )
        path.addLine(to: CGPoint(x: rect.minX + cut - 4, y: rect.minY + 6))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cut + 10, y: rect.minY),
            control: CGPoint(x: rect.minX + cut + 2, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct QuitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.65 : 0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.13))
            .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            .clipShape(Capsule())
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

private struct CelebrationDots: View {
    private let colors: [Color] = [.pink, .purple, electricCyan, .green, .orange, .yellow]

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<24) { index in
                Circle()
                    .fill(colors[index % colors.count].opacity(0.62))
                    .frame(width: CGFloat(5 + index % 4), height: CGFloat(5 + index % 4))
                    .position(
                        x: CGFloat((index * 83) % max(1, Int(geometry.size.width))),
                        y: CGFloat((index * 137) % max(1, Int(geometry.size.height)))
                    )
            }
        }
        .allowsHitTesting(false)
    }
}
