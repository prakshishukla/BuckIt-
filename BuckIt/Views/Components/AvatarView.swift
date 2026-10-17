import SwiftUI

/// Initials in a colored circle.
struct AvatarView: View {
    let name: String
    let initials: String
    var size: CGFloat = 40

    init(user: User?, size: CGFloat = 40) {
        self.name = user?.fullName ?? "?"
        self.initials = user?.initials ?? "?"
        self.size = size
    }

    private static let palette = ["#05668D", "#028090", "#513B56", "#7C6BB0", "#3F8F7B", "#8A5A83", "#034A66", "#5E7FA8"]

    private var color: Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Color(hex: Self.palette[sum % Self.palette.count])
    }

    var body: some View {
        Circle()
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.app(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(Theme.card, lineWidth: size > 30 ? 2 : 1.5))
            .accessibilityLabel(name)
    }
}

/// Overlapping avatars.
struct AvatarStack: View {
    let users: [User]
    var size: CGFloat = 30
    var maxCount = 5

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(users.prefix(maxCount)) { AvatarView(user: $0, size: size) }
            if users.count > maxCount {
                Circle().fill(Color.secondary.opacity(0.2)).frame(width: size, height: size)
                    .overlay(Text("+\(users.count - maxCount)").font(.app(.caption2, weight: .bold)))
            }
        }
    }
}
