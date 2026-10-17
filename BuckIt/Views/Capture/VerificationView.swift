import CoreLocation
import SwiftUI

/// Sends the photo to Gemini (plus on-device time/location checks), ticks the criteria off one by one, then celebrates.
struct VerificationView: View {
    enum Phase { case checking, verified, failed }

    @Environment(AppStore.self) private var store
    let challenge: Challenge
    let photo: UIImage
    let evidence: PhotoEvidence
    var onVerified: (VerificationResult) -> Void
    /// Post even though the check failed (no reward for sponsored items).
    var onPostAnyway: () -> Void
    var onRetake: () -> Void

    @State private var phase: Phase = .checking
    @State private var result: VerificationResult?
    @State private var revealed = 0
    @State private var checkProgress: CGFloat = 0
    @State private var confetti = 0
    @State private var errorMessage: String?
    @State private var scan = false

    private var usesGemini: Bool { store.verifier.usesGemini }

    private var rows: [CriterionResult] {
        result?.criteria ?? (challenge.verificationCriteria + ["Taken recently", "Taken near \(challenge.location ?? "Seattle")"])
            .map { CriterionResult(criterion: $0, met: true, why: "") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                photoCard
                    .padding(.top, 24)

                VStack(spacing: 6) {
                    if usesGemini {
                        Label("Gemini vision", systemImage: "sparkles")
                            .font(.app(.caption, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(LinearGradient(colors: [Theme.primary, Theme.lavender], startPoint: .leading, endPoint: .trailing),
                                        in: Capsule())
                    }
                    Text(title)
                        .font(.display(.title, weight: .heavy))
                        .contentTransition(.opacity)
                    Text(subtitle)
                        .font(.app(.subheadline))
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
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                if phase == .failed {
                    VStack(spacing: 10) {
                        if let errorMessage {
                            Text(errorMessage).font(.app(.footnote)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        Button("Retake photo", action: onRetake).buttonStyle(PrimaryButtonStyle())
                        Button(challenge.isSponsored ? "Post without reward" : "Post anyway", action: onPostAnyway)
                            .buttonStyle(SecondaryButtonStyle())
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
        case .checking: usesGemini ? "Verifying with Gemini…" : "Verifying (offline demo)…"
        case .verified: "Verified!"
        case .failed: "Couldn't verify"
        }
    }

    private var subtitle: String {
        switch phase {
        case .checking: "Checking your photo matches “\(challenge.title)”, plus when and where it was taken"
        case .verified:
            (result?.source == "Gemini" ? "Gemini confirmed your photo." : "Proof accepted.")
                + (challenge.isSponsored ? " Reward unlocked 🎉" : " Nice one 🎉")
        case .failed: "Your photo didn't pass every check. Try another shot?"
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
                        LinearGradient(colors: [.clear, Theme.primary.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
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
            let r = try await store.verifier.verify(photo: photo, challenge: challenge, evidence: evidence)
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
                    Image(systemName: row.skipped ? "minus.circle.fill" : (row.met ? "checkmark.circle.fill" : "xmark.circle.fill"))
                        .foregroundStyle(row.skipped ? Color.secondary : (row.met ? Theme.teal : .red))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .font(.app(.title3))
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.criterion)
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(revealed ? .primary : .secondary)
                    .shimmer(!revealed)
                if revealed, !row.why.isEmpty {
                    Text(row.why)
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Effects used by this screen

private struct Shimmer: ViewModifier {
    @State private var x: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: x * geo.size.width * 1.5)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { x = 1 }
            }
    }
}

private extension View {
    func shimmer(_ active: Bool) -> some View {
        Group {
            if active { modifier(Shimmer()) } else { self }
        }
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.53))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.69))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.35))
        return p
    }
}

/// Circle + check that draw themselves on as `progress` goes 0 → 1.
private struct AnimatedCheckmark: View {
    var progress: CGFloat
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.teal)
                .scaleEffect(progress > 0 ? 1 : 0.4)
                .opacity(progress > 0 ? 1 : 0)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.teal.opacity(0.35), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(-10)
            CheckShape()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Verified")
    }
}
