import CoreImage.CIFilterBuiltins
import MessageUI
import SwiftUI

// MARK: - Water splash

/// Droplets that burst out of the bucket each time `trigger` changes.
struct SplashView: View {
    var trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                Image(systemName: "drop.fill")
                    .font(.system(size: i.isMultiple(of: 2) ? 16 : 11))
                    .foregroundStyle(Theme.primary)
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
