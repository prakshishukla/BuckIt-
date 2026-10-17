import SwiftUI

enum Theme {
    static let water = Color("WaterBlue")
    static let navy = Color("LakeNavy")
    static let evergreen = Color("Evergreen")
    static let sunshine = Color("Sunshine")
    static let background = Color("AppBackground")
    static let card = Color("CardBackground")
    /// Navy that stays dark in dark mode (for text on white buttons, hero gradients).
    static let navyFixed = Color(hex: "#0B2545")
    static let cornerRadius: CGFloat = 20
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

extension Font {
    /// SF Pro Rounded for headings.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension ChallengeCategory {
    var tint: Color {
        switch self {
        case .hike: Theme.evergreen
        case .water: Theme.water
        case .park: Color(hex: "#3E9E5C")
        case .island: Color(hex: "#1E88A8")
        case .market: Color(hex: "#E08A1E")
        case .ride: Color(hex: "#5C6BC0")
        case .shopping: Color(hex: "#D84E7A")
        case .finance: Color(hex: "#1A1F71")
        }
    }
}

extension Challenge {
    var tint: Color { sponsor.map { Color(hex: $0.colorHex) } ?? category.tint }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }

    /// iOS 18 zoom transition source (card → detail); no-op on iOS 17.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// iOS 18 zoom transition destination; standard push on iOS 17.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var background: Color = Theme.water
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline))
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .shadow(color: background.opacity(0.35), radius: 10, y: 5)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.water

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline))
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// Small onboarding step header.
struct StepHeader: View {
    let step: Int
    let total: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.water : Color.secondary.opacity(0.25))
                        .frame(width: i == step ? 28 : 14, height: 6)
                }
            }
            Text(title).font(.rounded(.largeTitle, weight: .heavy))
            Text(subtitle).font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
