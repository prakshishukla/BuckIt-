import CoreLocation
import SwiftUI

/// Checks the photo against the sponsor's criteria, ticking them off one by one, then celebrates.
struct VerificationView: View {
    enum Phase { case checking, verified, failed }

    @Environment(AppStore.self) private var store
    let challenge: Challenge
    let photo: UIImage
    let location: CLLocation?
    let date: Date
    var onVerified: (VerificationResult) -> Void
    var onPostWithoutReward: () -> Void
    var onRetake: () -> Void

    @State private var phase: Phase = .checking
    @State private var result: VerificationResult?
    @State private var revealed = 0
    @State private var checkProgress: CGFloat = 0
    @State private var confetti = 0
    @State private var errorMessage: String?
    @State private var scan = false

    private var usesGemini: Bool { store.verifier is GeminiVerificationService }

    private var rows: [CriterionResult] {
        result?.criteria ?? challenge.criteria.map { CriterionResult(criterion: $0, met: true, why: "") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                photoCard
                    .padding(.top, 24)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.rounded(.title, weight: .heavy))
                        .contentTransition(.opacity)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        CriterionRow(row: row, revealed: index < revealed)
                    }
                    if let result, revealed >= rows.count {
                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text(result.confidence, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                if phase == .failed {
                    VStack(spacing: 10) {
                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        Button("Retake photo", action: onRetake).buttonStyle(PrimaryButtonStyle())
                        Button("Post without reward", action: onPostWithoutReward).buttonStyle(SecondaryButtonStyle())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.background.ignoresSafeArea())
        .overlay { ConfettiView(trigger: confetti) }
        .sensoryFeedback(.success, trigger: phase == .verified)
        .sensoryFeedback(.error, trigger: phase == .failed)
        .sensoryFeedback(.selection, trigger: revealed)
        .task { await run() }
    }

    private var title: String {
        switch phase {
        case .checking: usesGemini ? "Verifying with Gemini…" : "Verifying your proof…"
        case .verified: "Verified!"
        case .failed: "Couldn't verify"
        }
    }

    private var subtitle: String {
        switch phase {
        case .checking: "Checking your photo against \(challenge.sponsor.map { $0.name + "'s" } ?? "the") criteria"
        case .verified: result?.source == "Gemini" ? "Gemini confirmed your proof. Reward unlocked 🎉" : "Proof accepted. Reward unlocked 🎉"
        case .failed: "Your photo didn't meet every criterion. Try another shot?"
        }
    }

    private var photoCard: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: 170, height: 226)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if phase == .checking {
                    // scanning beam
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, Theme.water.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 60)
                            .offset(y: scan ? geo.size.height - 30 : -30)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { scan = true }
                    }
                }
            }
            .overlay {
                if phase == .verified {
                    AnimatedCheckmark(progress: checkProgress, size: 104)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }

    private func run() async {
        do {
            let r = try await store.verifier.verify(photo: photo, challenge: challenge, location: location, date: date)
            result = r
            for i in r.criteria.indices {
                try await Task.sleep(for: .milliseconds(430))
                withAnimation(.spring(duration: 0.35)) { revealed = i + 1 }
            }
            try await Task.sleep(for: .milliseconds(300))

            if r.verified {
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) { phase = .verified }
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) { checkProgress = 1 }
                confetti += 1
                try await Task.sleep(for: .seconds(2.0))
                onVerified(r)
            } else {
                withAnimation(.spring) { phase = .failed }
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            withAnimation(.spring) {
                revealed = 0
                phase = .failed
            }
        }
    }
}

private struct CriterionRow: View {
    let row: CriterionResult
    let revealed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if revealed {
                    Image(systemName: row.met ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(row.met ? Theme.evergreen : .red)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .font(.title3)
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.criterion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(revealed ? .primary : .secondary)
                    .shimmer(!revealed)
                if revealed, !row.why.isEmpty {
                    Text(row.why)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
