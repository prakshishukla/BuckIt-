import SafariServices
import SwiftUI

/// Our BuckIt Side Kick agent on UW Purple (UW sign-in may be required).
enum SideKick {
    static let purpleURL = URL(string: "https://purple.uw.edu/chat/1e754651-c8db-48ee-b518-b9702af7837d")!
}

/// In-app browser (shares Safari's sign-in, e.g. UW NetID for Purple).
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// "Need more ideas?" card that opens our Side Kick on UW Purple in an in-app browser.
/// Renders nothing when CLOUDFORCE = NO.
struct PurpleSideKickLink: View {
    @State private var showing = false

    var body: some View {
        if AppConfig.cloudforce {
            Button { showing = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.app(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "#4B2E83"), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Need more ideas?").font(.app(.subheadline, weight: .bold)).foregroundStyle(.primary)
                        Text("Ask our Side Kick on UW Purple").font(.app(.caption)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.app(.caption, weight: .bold)).foregroundStyle(Color(hex: "#4B2E83"))
                }
                .padding(12)
                .background(Color(hex: "#4B2E83").opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens UW Purple")
            .sheet(isPresented: $showing) { SafariView(url: SideKick.purpleURL).ignoresSafeArea() }
        }
    }
}
