import SwiftUI

/// Sponsor name in its brand color with a themed SF Symbol (or an official logo asset if one is added).
struct SponsorBadge: View {
    enum Style { case filled, onColor }

    let sponsor: Sponsor
    var style: Style = .filled
    var compact = false

    private var brand: Color { Color(hex: sponsor.colorHex) }

    var body: some View {
        HStack(spacing: 5) {
            if let asset = sponsor.logoAsset, UIImage(named: asset) != nil {
                Image(asset).resizable().scaledToFit().frame(height: compact ? 12 : 16)
            } else {
                Image(systemName: sponsor.symbol)
            }
            Text(sponsor.name).lineLimit(1)
        }
        .font(compact ? .app(.caption2, weight: .bold) : .app(.caption, weight: .bold))
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .foregroundStyle(style == .filled ? Color.white : brand)
        .background(style == .filled ? AnyShapeStyle(brand.gradient) : AnyShapeStyle(Color.white), in: Capsule())
        .accessibilityLabel("Sponsored by \(sponsor.name)")
    }
}

/// Hero illustration for a challenge: brand/category gradient, sun, rolling hills, and a big symbol.
struct SponsorArt: View {
    let challenge: Challenge

    var body: some View {
        let tint = challenge.tint
        ZStack {
            LinearGradient(colors: [tint.opacity(0.85), tint, Theme.plumFixed.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Theme.cream.gradient)
                .frame(width: 74, height: 74)
                .shadow(color: Theme.cream.opacity(0.6), radius: 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(24)
            HillsShape(crest: 0.62, phase: 0.6).fill(.white.opacity(0.14))
            HillsShape(crest: 0.74, phase: 2.1).fill(.white.opacity(0.22))
            Image(systemName: challenge.iconSymbol)
                .font(.system(size: 78, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            if let sponsor = challenge.sponsor {
                SponsorBadge(sponsor: sponsor, style: .onColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct HillsShape: Shape {
    var crest: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let baseY = rect.minY + rect.height * crest
        for x in stride(from: rect.minX, through: rect.maxX, by: 4) {
            let t = (x - rect.minX) / rect.width
            let y = baseY + sin(t * .pi * 2.2 + phase) * rect.height * 0.07 + sin(t * .pi * 5 + phase) * rect.height * 0.02
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
