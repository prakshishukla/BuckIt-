import CoreImage.CIFilterBuiltins
import MessageUI
import SwiftUI

// MARK: - Shimmer

struct Shimmer: ViewModifier {
    @State private var x: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: x * geo.size.width * 1.5)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { x = 1 }
            }
    }
}

extension View {
    func shimmer(_ active: Bool = true) -> some View {
        Group {
            if active { modifier(Shimmer()) } else { self }
        }
    }
}

// MARK: - Animated checkmark

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.53))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.69))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.35))
        return p
    }
}

/// Circle + check that draw themselves on as `progress` goes 0 → 1.
struct AnimatedCheckmark: View {
    var progress: CGFloat
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.evergreen)
                .scaleEffect(progress > 0 ? 1 : 0.4)
                .opacity(progress > 0 ? 1 : 0)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.evergreen.opacity(0.35), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(-10)
            CheckShape()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verified")
    }
}

// MARK: - Water splash

/// Droplets that burst out of the bucket each time `trigger` changes.
struct SplashView: View {
    var trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                Image(systemName: "drop.fill")
                    .font(.system(size: i.isMultiple(of: 2) ? 16 : 11))
                    .foregroundStyle(Theme.water)
                    .phaseAnimator([0, 1, 2], trigger: trigger) { view, phase in
                        let angle = Double.pi + Double(i) / 6 * Double.pi
                        let distance: Double = phase == 0 ? 0 : (phase == 1 ? 60 : 78)
                        view
                            .offset(x: cos(angle) * distance, y: sin(angle) * distance * 0.9 + (phase == 2 ? 24 : 0))
                            .opacity(phase == 1 ? 1 : 0)
                            .scaleEffect(phase == 0 ? 0.3 : 1)
                    } animation: { phase in
                        phase == 1 ? .easeOut(duration: 0.35) : .easeIn(duration: 0.35)
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - QR code

enum QRCode {
    private static let context = CIContext()
    private static var cache: [String: UIImage] = [:]

    static func image(for text: String) -> UIImage? {
        if let cached = cache[text] { return cached }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        let image = UIImage(cgImage: cg)
        cache[text] = image
        return image
    }
}

struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = QRCode.image(for: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("QR code for \(text)")
        } else {
            Image(systemName: "qrcode").resizable().scaledToFit()
        }
    }
}

// MARK: - Messages

/// SMS composer for invites. Not available on the Simulator: check `canSend` first.
struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: () -> Void

    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish()
        }
    }
}
