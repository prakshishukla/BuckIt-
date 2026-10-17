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

    private static let palette = ["#2F80ED", "#2E7D32", "#F2994A", "#9B51E0", "#EB5757", "#00A3A3", "#D49A00", "#3D5AFE"]

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
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
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
                    .overlay(Text("+\(users.count - maxCount)").font(.caption2.bold()))
            }
        }
    }
}
