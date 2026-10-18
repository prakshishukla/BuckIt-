import SwiftUI

/// Full-screen flow: camera → preview (pick list + item if needed) → Gemini verification → coupon (sponsored) or posted.
struct CaptureFlowView: View {
    enum Stage { case camera, preview, verifying, reward, posted }

    @Environment(AppStore.self) private var store
    let request: CaptureRequest

    @State private var stage: Stage = .camera
    @State private var photo: UIImage?
    @State private var selfie: UIImage?
    @State private var capturedAt = Date()
    @State private var metadata: PhotoMetadata?
    @State private var locationName = SeedData.fallbackLocation
    @State private var tagged: Set<UUID> = []
    @State private var caption = ""
    @State private var location = LocationService()
    @State private var listID: UUID?
    @State private var challengeID: String?
    @State private var coupon: Coupon?
    @State private var postID: UUID?

    /// Cover photos (bundled asset names) for an item posted with its demo photo, e.g. Visa's airplane tickets.
    private var coverNames: [String] {
        guard let challenge, let photo,
              photo.accessibilityIdentifier == SeedData.demoPhotoName(for: challenge) else { return [] }
        return SeedData.demoCoverPhotoNames[challenge.id] ?? []
    }

    /// The item being posted: fixed by the request, or chosen in the preview.
    private var challenge: Challenge? {
        request.challenge ?? challengeID.flatMap { store.challenge($0) }
    }

    var body: some View {
        ZStack {
            switch stage {
            case .camera:
                CaptureView(challenge: request.challenge, onCancel: close) { main, selfieShot, meta in
                    photo = main
                    selfie = selfieShot
                    metadata = meta
                    capturedAt = meta?.date ?? .now
                    withAnimation(.smooth) { stage = .preview }
                }
                .transition(.opacity)

            case .preview:
                if let photo {
                    CapturePreviewView(fixedChallenge: request.challenge, photo: photo,
                                       covers: coverNames.compactMap { UIImage(named: $0) },
                                       selfie: selfie, capturedAt: capturedAt,
                                       listID: $listID, challengeID: $challengeID,
                                       locationName: $locationName, tagged: $tagged, caption: $caption,
                                       onRetake: { withAnimation(.smooth) { stage = .camera } },
                                       onPost: { withAnimation(.smooth) { stage = .verifying } })
                        .transition(.move(edge: .trailing))
                }

            case .verifying:
                if let photo, let challenge {
                    VerificationView(challenge: challenge, photo: photo, evidence: evidence,
                                     onVerified: { _ in post(verified: true) },
                                     onPostAnyway: { post(verified: false) },
                                     onRetake: { withAnimation(.smooth) { stage = .camera } },
                                     onClose: close)
                        .transition(.opacity)
                }

            case .reward:
                if let coupon, let postID, let challenge {
                    CouponRevealView(coupon: coupon, challenge: challenge, postID: postID, onDone: close)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            case .posted:
                if let challenge {
                    PostedView(challenge: challenge, onDone: close)
                        .transition(.opacity)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        // The capture flow is a full-screen cover, so it shows the overflow itself (the tab view's copy is underneath).
        .overlay {
            if let colors = store.overflowColors {
                BucketOverflowView(colors: colors, bucketNumber: store.bucketNumber)
                    .transition(.opacity)
            }
        }
        .onAppear {
            listID = request.listID
            location.start()
        }
        .onChange(of: location.placeName) { _, name in
            // Use the real place name unless the user already typed their own.
            if let name, locationName == SeedData.fallbackLocation { locationName = name }
        }
    }

    /// Photo GPS/timestamp when the photo has them, otherwise the phone's location and capture time.
    private var evidence: PhotoEvidence {
        let photoLocation = metadata?.location
        return PhotoEvidence(location: photoLocation ?? location.location,
                             date: metadata?.date ?? capturedAt,
                             locationSource: photoLocation != nil ? "photo GPS" : "phone location",
                             dateSource: metadata?.date != nil ? "photo timestamp" : "capture time")
    }

    private func post(verified: Bool) {
        guard let photo, let challenge else { return }
        let result = store.completeChallenge(challenge, listID: listID, photo: photo, selfie: selfie,
                                             locationName: locationName, date: capturedAt,
                                             taggedUserIDs: Array(tagged), caption: caption, verified: verified,
                                             coverPhotoNames: coverNames)
        postID = result.post.id
        coupon = result.coupon
        withAnimation(.smooth) { stage = result.coupon != nil ? .reward : .posted }
    }

    private func close() {
        store.finishCapture()
    }
}
