import SwiftUI

/// Full-screen celebration when the bucket fills: water in the bucket's colors rises from the bottom,
/// swirls, bursts into confetti, then drains away to reveal a fresh empty bucket.
struct BucketOverflowView: View {
    let colors: [Color]
    let bucketNumber: Int

    @State private var start = Date()
    @State private var confetti = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            // 0 → 1.6s rise, hold, 4.0s → 5.0s drain
            let rise = min(1, t / 1.6)
            let drain = max(0, min(1, (t - 4.0) / 1.0))
            let height = (1 - pow(1 - rise, 3)) * 1.12 * (1 - drain)

            GeometryReader { geo in
                ZStack {
                    // Bands of water in the bucket's colors, rising together with swirling wavy boundaries.
                    let bands = Array(repeating: colors, count: max(1, 8 / max(colors.count, 1) + 1)).flatMap { $0 }.prefix(8)
                    let n = bands.count
                    ForEach(Array(bands.enumerated()).reversed(), id: \.offset) { k, color in
                        WaveShape(level: height * Double(k + 1) / Double(n),
                                  phase: t * (1.6 + Double(k) * 0.35) + Double(k) * 1.9,
                                  amplitude: 14 + 10 * sin(t * 1.3 + Double(k)))
                            .fill(LinearGradient(colors: [color.opacity(0.92), color], startPoint: .top, endPoint: .bottom))
                    }

                    // Swirl: a slowly rotating ring of the same colors, softly blended over the water.
                    AngularGradient(colors: colors + [colors[0]], center: .center, angle: .degrees(t * 140))
                        .blur(radius: 14)
                        .opacity(0.35)
                        .blendMode(.softLight)
                        .mask(WaveShape(level: height, phase: t * 1.6, amplitude: 18))

                    // Bubbles
                    ForEach(0..<14, id: \.self) { i in
                        let x = (Double(i) * 0.137 + 0.05).truncatingRemainder(dividingBy: 1)
                        let speed = 0.18 + Double(i % 5) * 0.05
                        let y = 1 - ((t * speed + Double(i) * 0.21).truncatingRemainder(dividingBy: 1)) * height
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 8 + CGFloat(i % 4) * 5)
                            .position(x: geo.size.width * x, y: geo.size.height * y)
                            .opacity(height > 0.15 ? 1 : 0)
                    }

                    VStack(spacing: 10) {
                        Text("Bucket full! 🎉")
                            .font(.display(size: 40, weight: .heavy))
                        Text("Starting Bucket #\(bucketNumber)")
                            .font(.app(.title3, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    .opacity(t > 1.0 && t < 4.2 ? 1 : 0)
                    .scaleEffect(t > 1.0 ? 1 : 0.7)
                    .animation(.spring(duration: 0.5, bounce: 0.4), value: t > 1.0)
                    .animation(.easeOut(duration: 0.3), value: t < 4.2)
                }
            }
        }
        .overlay { ConfettiView(trigger: confetti) }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .sensoryFeedback(.success, trigger: confetti)
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(1.5))
            confetti += 1
            try? await Task.sleep(for: .seconds(1.1))
            confetti += 1
        }
        .accessibilityElement()
        .accessibilityLabel("Bucket full. Starting bucket number \(bucketNumber).")
    }
}

/// Profile → Bucket colors: pick the water color for each activity type.
struct BucketColorsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ChallengeCategory.allCases) { category in
                        ColorPicker(selection: Binding(get: { store.waterColor(category) },
                                                       set: { store.setWaterColor($0, for: category) }),
                                    supportsOpacity: false) {
                            Label(category.label, systemImage: category.symbol)
                                .font(.app(.body, weight: .medium))
                        }
                    }
                } footer: {
                    Text("Each completed item adds a layer of water in its activity type's color.")
                }
                Section {
                    Button("Reset to default colors", role: .destructive) { store.resetWaterColors() }
                }
            }
            .navigationTitle("Bucket colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
