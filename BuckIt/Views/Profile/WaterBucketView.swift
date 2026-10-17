import SwiftUI

/// BuckIt's "streak pet": a bucket that fills with animated water instead of growing.
/// `level` is 0...1 and animates smoothly with `withAnimation`.
/// `layers` colors each drop (bottom first) by the activity type that earned it; empty = plain blue water.
struct WaterBucketView: View {
    var level: Double
    var size: CGFloat = 180
    var outline: Color = Theme.plum
    var layers: [Color] = []

    var body: some View {
        let lineWidth = max(2.5, size * 0.035)
        let amplitude: Double = min(1, level * 8) * Double(size) * 0.03

        ZStack(alignment: .top) {
            BucketHandle()
                .stroke(outline, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size * 0.78, height: size * 0.3)
                .offset(y: -size * 0.2)

            ZStack {
                BucketShape().fill(Theme.card)

                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    if layers.isEmpty {
                        ZStack {
                            WaveShape(level: level, phase: t * 1.7 + 1.4, amplitude: amplitude * 0.8)
                                .fill(Theme.primary.opacity(0.35))
                            WaveShape(level: level, phase: t * 2.3, amplitude: amplitude)
                                .fill(LinearGradient(colors: [Color(hex: "#2BA3B5"), Theme.primary, Theme.deepFixed],
                                                     startPoint: .top, endPoint: .bottom))
                        }
                    } else {
                        LayeredWater(layers: layers, level: level, t: t, amplitude: amplitude, size: size)
                    }
                }
                .clipShape(BucketShape())

                // drop markers
                VStack(spacing: 0) {
                    ForEach(1..<SeedData.dropsPerBucket, id: \.self) { _ in
                        Spacer()
                        Capsule().fill(outline.opacity(0.18)).frame(width: size * 0.07, height: 2)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, size * 0.2)
                .padding(.vertical, size * 0.06)

                BucketShape().stroke(outline, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))

                Capsule()
                    .fill(outline)
                    .frame(width: size * 1.04, height: lineWidth * 2.2)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: -lineWidth)
            }
            .frame(width: size, height: size * 0.9)
        }
        .frame(width: size * 1.05, height: size * 1.12, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Water bucket \(Int(level * 100)) percent full")
    }
}

struct BucketShape: Shape {
    func path(in r: CGRect) -> Path {
        let bottomInset = r.width * 0.14
        let corner = r.width * 0.09
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - bottomInset, y: r.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: r.maxX - bottomInset - corner, y: r.maxY),
                       control: CGPoint(x: r.maxX - bottomInset - corner * 0.1, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + bottomInset + corner, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + bottomInset, y: r.maxY - corner),
                       control: CGPoint(x: r.minX + bottomInset + corner * 0.1, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct BucketHandle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
        return p
    }
}

/// Sine-wave water surface; `level` and `amplitude` are animatable, `phase` is driven by TimelineView.
struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var amplitude: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, amplitude) }
        set { level = newValue.first; amplitude = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        let clamped = min(max(level, 0), 1.08)
        let surface = r.maxY - r.height * clamped
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        for x in stride(from: r.minX, through: r.maxX, by: 3) {
            let rel = (x - r.minX) / r.width
            p.addLine(to: CGPoint(x: x, y: surface + sin(rel * .pi * 2.4 + phase) * amplitude))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Stacked bands of water, one per drop. The top band rises with `level`; lower bands sit at fixed heights
/// with gently wavy boundaries. Drawn back-to-front: the top band first, then each lower band over it.
private struct LayeredWater: View {
    let layers: [Color]
    let level: Double
    let t: TimeInterval
    let amplitude: Double
    let size: CGFloat

    var body: some View {
        let n = layers.count
        let step = 1 / Double(SeedData.dropsPerBucket)
        ZStack {
            WaveShape(level: level, phase: t * 1.7 + 1.4, amplitude: amplitude * 0.8)
                .fill(layers[n - 1].opacity(0.45))
            WaveShape(level: level, phase: t * 2.3, amplitude: amplitude)
                .fill(LinearGradient(colors: [layers[n - 1].opacity(0.85), layers[n - 1]], startPoint: .top, endPoint: .bottom))
            ForEach(Array((0..<max(0, n - 1)).reversed()), id: \.self) { k in
                WaveShape(level: Double(k + 1) * step, phase: t * 0.9 + Double(k) * 1.3, amplitude: Double(size) * 0.007)
                    .fill(LinearGradient(colors: [layers[k].opacity(0.9), layers[k]], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}
