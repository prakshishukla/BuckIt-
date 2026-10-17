import SwiftUI

/// 3D card flip revealing the coupon (already saved to the wallet).
struct CouponRevealView: View {
    @Environment(AppStore.self) private var store
    let coupon: Coupon
    let challenge: Challenge
    let postID: UUID
    var onDone: () -> Void

    @State private var angle: Double = 0
    @State private var shared = false
    @State private var confetti = 0

    private var flipped: Bool { angle >= 90 }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text(flipped ? "Reward unlocked!" : "You earned a reward")
                    .font(.rounded(.title, weight: .heavy))
                    .contentTransition(.opacity)
                Text(flipped ? "Show this code at checkout." : "Tap the card to reveal it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .animation(.smooth, value: flipped)

            FlipCard(angle: angle) {
                CouponBack(sponsor: coupon.sponsor)
            } back: {
                CouponCardView(coupon: coupon, showsActions: false)
            }
            .padding(.horizontal, 20)
            .onTapGesture(perform: reveal)

            if flipped {
                Label("Saved to Wallet", systemImage: "checkmark.circle.fill")
                    .font(.rounded(.headline))
                    .foregroundStyle(Theme.evergreen)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    // Coupons are saved automatically when minted.
                } label: {
                    Label("Saved to Wallet", systemImage: "wallet.pass.fill")
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.evergreen))
                .disabled(true)

                Button {
                    store.shareReward(postID: postID, headline: coupon.headline)
                    withAnimation(.snappy) { shared = true }
                } label: {
                    Label(shared ? "Shared to feed" : "Share to feed", systemImage: shared ? "checkmark" : "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(shared)

                Button("Done", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .opacity(flipped ? 1 : 0)
            .animation(.smooth.delay(0.3), value: flipped)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay { ConfettiView(trigger: confetti) }
        .sensoryFeedback(.success, trigger: flipped)
        .task {
            try? await Task.sleep(for: .seconds(0.7))
            reveal()
        }
    }

    private func reveal() {
        guard angle == 0 else { return }
        withAnimation(.spring(duration: 0.9, bounce: 0.25)) { angle = 180 }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            confetti += 1
        }
    }
}

/// Shows `front` until the card turns past 90°, then the (counter-rotated) `back`.
private struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front()
            } else {
                back().rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

private struct CouponBack: View {
    let sponsor: Sponsor

    var body: some View {
        let brand = Color(hex: sponsor.colorHex)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [brand, brand.opacity(0.7), Theme.navyFixed], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 64))
                    .symbolEffect(.pulse, options: .repeating)
                SponsorBadge(sponsor: sponsor, style: .onColor)
            }
            .foregroundStyle(.white)
        }
        .frame(height: 260)
        .shadow(color: brand.opacity(0.35), radius: 18, y: 10)
    }
}

/// Shown after posting a non-sponsored challenge: the bucket fills a level.
struct PostedView: View {
    @Environment(AppStore.self) private var store
    let challenge: Challenge
    var onDone: () -> Void

    @State private var level: Double = 0
    @State private var splash = 0
    @State private var confetti = 0

    var body: some View {
        let count = store.me.completedCount
        VStack(spacing: 20) {
            Spacer()
            ZStack(alignment: .top) {
                WaterBucketView(level: level, size: 190)
                SplashView(trigger: splash).padding(.top, 30)
            }
            Text("Posted!")
                .font(.rounded(.largeTitle, weight: .heavy))
            Text("**\(challenge.title)** is in the feed.\n+1 drop in your bucket 💧")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay { ConfettiView(trigger: confetti) }
        .sensoryFeedback(.success, trigger: splash)
        .onAppear {
            level = AppStore.level(for: max(0, count - 1))
        }
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            let overflows = count > 0 && count % SeedData.dropsPerBucket == 0
            withAnimation(.spring(duration: 1.0, bounce: 0.35)) { level = overflows ? 1 : AppStore.level(for: count) }
            splash += 1
            confetti += 1
        }
    }
}
