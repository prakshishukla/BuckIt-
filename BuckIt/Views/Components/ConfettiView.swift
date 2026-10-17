import SwiftUI

/// Lightweight Canvas confetti burst. Increment `trigger` to fire.
struct ConfettiView: View {
    var trigger: Int

    private struct Piece {
        var angle: Double
        var speed: Double
        var spin: Double
        var size: CGSize
        var color: Color
        var delay: Double
        var originX: Double
    }

    @State private var start: Date?
    @State private var pieces: [Piece] = []

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let tt = max(0, t - p.delay)
                    let x = size.width * p.originX + cos(p.angle) * p.speed * tt
                    let y = size.height * 0.38 + sin(p.angle) * p.speed * tt + 0.5 * 950 * tt * tt
                    var ctx = context
                    ctx.opacity = max(0, 1 - max(0, tt - 1.5) / 0.8)
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(p.spin * tt))
                    let rect = CGRect(x: -p.size.width / 2, y: -p.size.height / 2, width: p.size.width, height: p.size.height)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onChange(of: trigger) { fire() }
    }

    private func fire() {
        let colors: [Color] = [Theme.primary, Theme.teal, Theme.plumFixed, Theme.lavender, Theme.cream, Color(hex: "#7FC8D6")]
        pieces = (0..<110).map { _ in
            Piece(angle: Double.random(in: (-0.92 * Double.pi)...(-0.08 * Double.pi)),
                  speed: Double.random(in: 320...950),
                  spin: Double.random(in: -12...12),
                  size: CGSize(width: Double.random(in: 6...11), height: Double.random(in: 4...7)),
                  color: colors.randomElement() ?? .blue,
                  delay: Double.random(in: 0...0.15),
                  originX: Double.random(in: 0.35...0.65))
        }
        let fired = Date()
        start = fired
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.8))
            if start == fired { start = nil }
        }
    }
}
