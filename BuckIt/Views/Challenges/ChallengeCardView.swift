import SwiftUI

struct ChallengeCardView: View {
    @Environment(AppStore.self) private var store
    let challenge: Challenge

    var body: some View {
        let done = store.myPost(for: challenge.id)

        HStack(spacing: 14) {
            ZStack {
                if let done, let thumb = PhotoStore.image(done.photoFilename) {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Rectangle().fill(challenge.tint.gradient)
                    Image(systemName: challenge.iconSymbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                if let sponsor = challenge.sponsor {
                    SponsorBadge(sponsor: sponsor, compact: true)
                }
                Text(challenge.title)
                    .font(.rounded(.headline))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let location = challenge.location {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    ChipView.commitment(challenge.commitment)
                    if let reward = challenge.reward {
                        Text("🎁 \(reward.headline)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.evergreen)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            if done != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.evergreen)
                    .accessibilityLabel("Completed")
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .card(padding: 14)
        .contentShape(Rectangle())
    }
}
