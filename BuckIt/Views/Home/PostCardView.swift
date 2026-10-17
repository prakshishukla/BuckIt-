import SwiftUI

struct PostCardView: View {
    @Environment(AppStore.self) private var store
    let post: Post
    @State private var showComments = false
    @State private var reactionTaps = 0

    static let reactionEmojis = ["🔥", "🙌", "😂", "🌊"]

    var body: some View {
        let challenge = SeedData.challenge(post.challengeID)
        let author = store.user(post.userID)
        let tagged = post.taggedUserIDs.compactMap { store.user($0) }

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                AvatarView(user: author, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(author?.id == store.me.id ? "You" : (author?.firstName ?? "Someone"))
                            .font(.headline)
                        if post.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.water)
                                .accessibilityLabel("Verified")
                        }
                    }
                    Text(post.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let sponsor = challenge?.sponsor {
                    SponsorBadge(sponsor: sponsor, compact: true)
                }
            }

            Text("completed **\(challenge?.title ?? "a challenge")**")
                .font(.subheadline)

            DualPhotoView(main: PhotoStore.image(post.photoFilename), selfie: PhotoStore.image(post.selfieFilename))
                .overlay(alignment: .bottomLeading) {
                    Label(post.locationName, systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }

            if let caption = post.caption {
                Text(caption).font(.body)
            }

            if !tagged.isEmpty {
                HStack(spacing: 6) {
                    AvatarStack(users: tagged, size: 22)
                    Text("with " + tagged.map(\.firstName).formatted(.list(type: .and)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let reward = post.sharedRewardHeadline, let sponsor = challenge?.sponsor {
                Label("Unlocked \(reward) at \(sponsor.name)", systemImage: "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.evergreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.evergreen.opacity(0.12), in: Capsule())
            }

            // Reactions + comments
            HStack(spacing: 8) {
                ForEach(Self.reactionEmojis, id: \.self) { emoji in
                    let users = post.reactions[emoji] ?? []
                    let mine = users.contains(store.me.id)
                    Button {
                        reactionTaps += 1
                        withAnimation(.snappy) { store.toggleReaction(emoji, postID: post.id) }
                    } label: {
                        HStack(spacing: 3) {
                            Text(emoji)
                            if !users.isEmpty {
                                Text("\(users.count)")
                                    .font(.caption.weight(.bold))
                                    .contentTransition(.numericText())
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(mine ? Theme.water.opacity(0.18) : Color.secondary.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(mine ? Theme.water : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(emoji) \(users.count)")
                }
                Spacer()
                Button {
                    showComments = true
                } label: {
                    Label("\(post.comments.count)", systemImage: "bubble.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(post.comments.count) comments")
            }
        }
        .card(padding: 14)
        .sensoryFeedback(.impact(weight: .light), trigger: reactionTaps)
        .sheet(isPresented: $showComments) {
            CommentsSheet(postID: post.id)
        }
    }
}

/// BeReal-style main photo with a draggable selfie inset. Tap the inset to swap.
struct DualPhotoView: View {
    let main: UIImage?
    let selfie: UIImage?
    var cornerRadius: CGFloat = 18

    @State private var swapped = false
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    private let insetSize = CGSize(width: 92, height: 122)
    private let margin: CGFloat = 12

    var body: some View {
        let big = swapped ? selfie : main
        let small = swapped ? main : selfie

        Color.secondary.opacity(0.12)
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                if let big {
                    Image(uiImage: big).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                if let small {
                    GeometryReader { geo in
                        Image(uiImage: small)
                            .resizable()
                            .scaledToFill()
                            .frame(width: insetSize.width, height: insetSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white, lineWidth: 2.5))
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                            .offset(x: margin + offset.width + drag.width, y: margin + offset.height + drag.height)
                            .onTapGesture { withAnimation(.snappy) { swapped.toggle() } }
                            .gesture(
                                DragGesture()
                                    .updating($drag) { value, state, _ in state = value.translation }
                                    .onEnded { value in
                                        let maxX = geo.size.width - insetSize.width - margin * 2
                                        let maxY = geo.size.height - insetSize.height - margin * 2
                                        let x = offset.width + value.translation.width
                                        let y = offset.height + value.translation.height
                                        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                                            // Snap to the nearest side, like BeReal.
                                            offset = CGSize(width: x > maxX / 2 ? maxX : 0, height: min(max(0, y), maxY))
                                        }
                                    }
                            )
                            .accessibilityLabel("Selfie. Tap to swap photos.")
                    }
                }
            }
    }
}
