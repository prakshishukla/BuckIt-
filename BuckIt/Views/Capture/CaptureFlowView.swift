import SwiftUI

/// Full-screen flow: camera → preview → (verify → coupon) or posted.
struct CaptureFlowView: View {
    enum Stage { case camera, preview, verifying, reward, posted }

    @Environment(AppStore.self) private var store
    let challenge: Challenge

    @State private var stage: Stage = .camera
    @State private var photo: UIImage?
    @State private var selfie: UIImage?
    @State private var capturedAt = Date()
    @State private var locationName = SeedData.fallbackLocation
    @State private var tagged: Set<UUID> = []
    @State private var caption = ""
    @State private var location = LocationService()
    @State private var coupon: Coupon?
    @State private var postID: UUID?

    var body: some View {
        ZStack {
            switch stage {
            case .camera:
                CaptureView(challenge: challenge, onCancel: close) { main, selfieShot in
                    photo = main
                    selfie = selfieShot
                    capturedAt = .now
                    withAnimation(.smooth) { stage = .preview }
                }
                .transition(.opacity)

            case .preview:
                if let photo {
                    CapturePreviewView(challenge: challenge, photo: photo, selfie: selfie, capturedAt: capturedAt,
                                       locationName: $locationName, tagged: $tagged, caption: $caption,
                                       onRetake: { withAnimation(.smooth) { stage = .camera } },
                                       onPost: post)
                        .transition(.move(edge: .trailing))
                }

            case .verifying:
                if let photo {
                    VerificationView(challenge: challenge, photo: photo, location: location.location, date: capturedAt,
                                     onVerified: { _ in complete(verified: true) },
                                     onPostWithoutReward: { complete(verified: false) },
                                     onRetake: { withAnimation(.smooth) { stage = .camera } })
                        .transition(.opacity)
                }

            case .reward:
                if let coupon, let postID {
                    CouponRevealView(coupon: coupon, challenge: challenge, postID: postID, onDone: close)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            case .posted:
                PostedView(challenge: challenge, onDone: close)
                    .transition(.opacity)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { location.start() }
        .onChange(of: location.placeName) { _, name in
            // Use the real place name unless the user already typed their own.
            if let name, locationName == SeedData.fallbackLocation { locationName = name }
        }
    }

    private func post() {
        if challenge.isSponsored {
            withAnimation(.smooth) { stage = .verifying }
        } else {
            complete(verified: false)
        }
    }

    private func complete(verified: Bool) {
        guard let photo else { return }
        let result = store.completeChallenge(challenge, photo: photo, selfie: selfie, locationName: locationName,
                                             date: capturedAt, taggedUserIDs: Array(tagged), caption: caption,
                                             verified: verified)
        postID = result.post.id
        coupon = result.coupon
        withAnimation(.smooth) { stage = result.coupon != nil ? .reward : .posted }
    }

    private func close() {
        store.finishCapture()
    }
}
