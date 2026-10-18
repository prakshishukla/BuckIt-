import SwiftUI

/// Shown right after "Continue" on the sign-in screen, before the account is set up; also viewable from
/// Profile → Settings. Must be accepted to continue. Content matches AI_SYSTEM.md.
struct PrivacyAgreementView: View {
    enum Mode { case accept, view }

    static let version = "1.0 · October 2026"

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var mode: Mode = .accept
    @State private var agreed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if mode == .accept {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.app(.title2, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Theme.primary.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("Your privacy").font(.display(.largeTitle, weight: .heavy))
                        Text("Before you create your account, here's what BuckIt does with your data, in plain words.")
                            .font(.app(.body)).foregroundStyle(.secondary)
                    }
                }

                ForEach(Self.sections(cloudforce: AppConfig.cloudforce), id: \.title) { section in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: section.symbol)
                            .font(.app(.headline))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title).font(.app(.headline, weight: .semibold))
                            Text(section.body).font(.app(.subheadline)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text("Version \(Self.version)")
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)

                if mode == .view, let date = store.state.privacyAcceptedAt {
                    Label("You agreed on \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.seal.fill")
                        .font(.app(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if mode == .accept { acceptBar }
        }
        .navigationTitle(mode == .view ? "Privacy agreement" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .view {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var acceptBar: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { agreed.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: agreed ? "checkmark.square.fill" : "square")
                        .font(.app(.title3))
                        .foregroundStyle(agreed ? Theme.primary : .secondary)
                    Text("I've read and agree to the BuckIt Privacy Agreement.")
                        .font(.app(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: agreed)

            Button("Agree and continue") { store.acceptPrivacy(version: Self.version) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!agreed)
            Button("Decline") { store.declinePrivacy() }
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private struct Section {
        var symbol: String
        var title: String
        var body: String
    }

    private static func sections(cloudforce: Bool) -> [Section] {
        var list = [
            Section(symbol: "iphone", title: "Stored on your phone",
                    body: "Your name, city, season, lists, posts, photos, selfies and coupons are saved on this device. This demo has no BuckIt account server."),
            Section(symbol: "sparkles", title: "Photo check with Google Gemini",
                    body: "When you post proof, that photo (resized, with its location data removed) and the item's details are sent to the BuckIt AI server and Google Gemini to check it matches. The server doesn't keep the photo; its audit log keeps only a fingerprint (hash) of it and Gemini's verdict."),
            Section(symbol: "location.fill", title: "Location",
                    body: "Your location, or the GPS in a photo, is used on your phone to check a photo was taken near the item. It is never sent to our server or to Gemini."),
            Section(symbol: "person.2.fill", title: "Friends and selfies",
                    body: "Friends' names, tags and your selfies are never sent to AI. Contacts are only used if you allow it, to find friends on BuckIt."),
            Section(symbol: "lightbulb.fill", title: "AI suggestions",
                    body: "Idea suggestions send the list's name, its item titles, your city, the season and any mood you type. Nothing is added to your list unless you pick it."),
            Section(symbol: "tag.fill", title: "Sponsors",
                    body: "Sponsors only see totals (how many people added, completed or redeemed a challenge), never who you are. If you choose to share what you bought with a coupon, that note appears on your post and in the sponsor's dashboard."),
            Section(symbol: "hand.thumbsup.fill", title: "You're in control",
                    body: "A failed photo check never stops you from posting. Profile → Settings → Reset app deletes everything BuckIt stored on this device."),
        ]
        if cloudforce {
            list.insert(Section(symbol: "bubble.left.and.text.bubble.right.fill", title: "UW Purple",
                                body: "The \"Need more ideas?\" link opens our Side Kick on UW Purple. BuckIt sends it nothing; what you type there is covered by UW Purple's own terms."),
                        at: list.count - 1)
        }
        return list
    }
}
