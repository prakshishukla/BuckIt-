import SwiftUI

struct ChallengeCardView: View {
    @Environment(AppStore.self) private var store
    let challenge: Challenge
    /// List members who've done it; shown as avatars on the card.
    var completers: [User] = []

    var body: some View {
        let done = store.myPost(for: challenge.id)

        HStack(spacing: 14) {
            Group {
                if let done, let thumb = PhotoStore.image(done.photoFilename) {
                    Image(uiImage: thumb).resizable().scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ChallengeThumb(challenge: challenge, size: 64)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                if let sponsor = challenge.sponsor {
                    SponsorBadge(sponsor: sponsor, compact: true)
                }
                Text(challenge.title)
                    .font(.display(.headline))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let location = challenge.location {
                    Label(location, systemImage: "mappin")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    ChipView.commitment(challenge.commitment)
                    if let reward = challenge.reward {
                        Text("🎁 \(reward.headline)")
                            .font(.app(.caption, weight: .semibold))
                            .foregroundStyle(Theme.teal)
                            .lineLimit(1)
                    }
                }
                if !completers.isEmpty {
                    HStack(spacing: 6) {
                        AvatarStack(users: completers, size: 22, maxCount: 4)
                        Text(doneText)
                            .font(.app(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                    .accessibilityElement(children: .combine)
                }
            }

            Spacer(minLength: 0)

            if done != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.app(.title2))
                    .foregroundStyle(Theme.teal)
                    .accessibilityLabel("Completed")
            } else {
                Image(systemName: "chevron.right")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .card(padding: 14)
        .contentShape(Rectangle())
    }

    private var doneText: String {
        let names = completers.map { $0.id == store.me.id ? "You" : $0.firstName }
        switch names.count {
        case 1: return "\(names[0]) did this"
        case 2: return "\(names[0]) & \(names[1]) did this"
        default: return "\(names[0]) & \(names.count - 1) others did this"
        }
    }
}
