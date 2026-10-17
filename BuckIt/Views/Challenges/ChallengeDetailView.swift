import SwiftUI

struct ChallengeDetailView: View {
    @Environment(AppStore.self) private var store
    let challenge: Challenge
    @State private var submitTaps = 0
    @State private var toast: String?

    var body: some View {
        let myPost = store.myPost(for: challenge.id)
        let coupon = store.coupon(for: challenge.id)
        let friends = (SeedData.friendCompletions[challenge.id] ?? []).compactMap { store.user($0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero

                VStack(alignment: .leading, spacing: 10) {
                    Text(challenge.title)
                        .font(.display(.largeTitle, weight: .heavy))
                    HStack(spacing: 8) {
                        if let location = challenge.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.app(.subheadline))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 8) {
                        ChipView.commitment(challenge.commitment, compact: false)
                        ChipView(text: challenge.category.label, symbol: challenge.category.symbol, tint: challenge.category.tint)
                    }
                    addToList
                        .padding(.top, 4)
                }

                Text(challenge.description)
                    .font(.app(.body))

                if challenge.isSponsored {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What to capture").font(.display(.headline))
                        ForEach(challenge.criteria, id: \.self) { criterion in
                            Label {
                                Text(criterion).font(.app(.subheadline))
                            } icon: {
                                Image(systemName: "camera.viewfinder").foregroundStyle(Theme.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    if let reward = challenge.reward, let sponsor = challenge.sponsor {
                        RewardPreviewCard(reward: reward, sponsor: sponsor, coupon: coupon)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Friends who've done it").font(.display(.headline))
                    if friends.isEmpty {
                        Text("Nobody yet. Be the first in your crew! 🏁")
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(friends) { friend in
                                    NavigationLink(value: FriendRoute(id: friend.id)) {
                                        VStack(spacing: 5) {
                                            AvatarView(user: friend, size: 44)
                                            Text(friend.firstName).font(.app(.caption, weight: .medium)).foregroundStyle(.primary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if let myPost {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("You did it \(myPost.date.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle.fill")
                            .font(.display(.headline))
                            .foregroundStyle(Theme.teal)
                        DualPhotoView(main: PhotoStore.image(myPost.photoFilename), selfie: PhotoStore.image(myPost.selfieFilename))
                            .frame(maxWidth: 220)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                submitTaps += 1
                store.startCapture(challenge)
            } label: {
                Label(myPost == nil ? "Post it" : "Post again", systemImage: "camera.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: submitTaps)
        .toast($toast)
    }

    @ViewBuilder
    private var hero: some View {
        if let name = challenge.imageName, let image = UIImage(named: name) {
            Color.clear
                .frame(height: 240)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)
        } else {
            SponsorArt(challenge: challenge)
                .frame(height: 220)
        }
    }

    /// Adds this item to one of my lists that doesn't have it yet.
    @ViewBuilder
    private var addToList: some View {
        let missing = store.listsMissing(challenge.id)
        if missing.isEmpty {
            Label("On all your lists", systemImage: "checkmark.circle.fill")
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.teal)
        } else {
            Menu {
                Section("Add to…") {
                    ForEach(missing) { list in
                        Button("\(list.emoji) \(list.name)") {
                            withAnimation { store.addItem(challenge.id, to: list.id) }
                            toast = "Added to \(list.name)"
                        }
                    }
                }
            } label: {
                Label("Add to list", systemImage: "plus.circle.fill")
                    .font(.app(.subheadline, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(Theme.primary, in: Capsule())
            }
        }
    }
}

/// Reward card: blurred and locked until the challenge is completed.
private struct RewardPreviewCard: View {
    let reward: RewardTemplate
    let sponsor: Sponsor
    let coupon: Coupon?

    var body: some View {
        let unlocked = coupon != nil
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Reward", systemImage: "gift.fill").font(.display(.headline))
                Spacer()
                Text("DEMO").font(.app(.caption2, weight: .heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.25), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.headline).font(.display(.title2, weight: .heavy))
                Text(reward.detail).font(.app(.subheadline)).opacity(0.9)
                Text(unlocked ? "Code \(coupon?.code ?? "") is in your Wallet" : "\(reward.codePrefix)-XXXXXX · expires \(reward.expiresInDays) days after unlock")
                    .font(.caption.monospaced())
                    .opacity(0.85)
            }
            .blur(radius: unlocked ? 0 : 7)
            .overlay {
                if !unlocked {
                    Label("Complete to unlock", systemImage: "lock.fill")
                        .font(.app(.subheadline, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.primary)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(hex: sponsor.colorHex).gradient, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(unlocked ? "Reward unlocked: \(reward.headline)" : "Reward locked. Complete the challenge to unlock.")
    }
}
