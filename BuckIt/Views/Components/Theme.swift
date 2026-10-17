import SwiftUI

enum Theme {
    // Primary
    static let primary = Color("BrandPrimary")        // #05668D
    static let teal = Color("BrandTeal")              // #028090
    static let plum = Color("BrandPlum")              // #513B56 (lightens in dark mode, used for ink/outlines)
    // Secondary
    static let lavender = Color("BrandLavender")      // #B0A3D4
    static let cream = Color("BrandCream")            // #F0F3BD

    static let background = Color("AppBackground")
    static let card = Color("CardBackground")
    /// Plum that stays dark in dark mode (text on light buttons, hero gradients).
    static let plumFixed = Color(hex: "#513B56")
    /// Deep shade of the primary for gradients.
    static let deepFixed = Color(hex: "#034A66")
    static let cornerRadius: CGFloat = 20
}

/// Playfair Display for titles, DM Sans for everything else. Both scale with Dynamic Type.
enum AppFont {
    static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }

    static func displayName(_ weight: Font.Weight) -> String {
        switch weight {
        case .heavy, .black: "PlayfairDisplay-ExtraBold"
        case .bold: "PlayfairDisplay-Bold"
        default: "PlayfairDisplay-SemiBold"
        }
    }

    static func textName(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "DMSans-Bold"
        case .semibold: "DMSans-SemiBold"
        case .medium: "DMSans-Medium"
        default: "DMSans-Regular"
        }
    }
}

extension Font {
    /// Playfair Display, for titles and headings.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .custom(AppFont.displayName(weight), size: AppFont.baseSize(style), relativeTo: style)
    }

    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom(AppFont.displayName(weight), size: size)
    }

    /// DM Sans, for body copy and UI text.
    static func app(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let resolved = weight ?? (style == .headline ? .semibold : .regular)
        return .custom(AppFont.textName(resolved), size: AppFont.baseSize(style), relativeTo: style)
    }

    static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(AppFont.textName(weight), size: size)
    }
}

/// UIKit-drawn chrome (navigation titles, segmented controls, tab bar) picks up the same fonts.
enum AppearanceSetup {
    static func apply() {
        let plum = UIColor(named: "BrandPlum") ?? .label
        if let large = UIFont(name: "PlayfairDisplay-Bold", size: 34),
           let inline = UIFont(name: "PlayfairDisplay-Bold", size: 18) {
            let nav = UINavigationBar.appearance()
            nav.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large), .foregroundColor: plum]
            nav.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline), .foregroundColor: plum]
        }
        if let seg = UIFont(name: "DMSans-SemiBold", size: 14) {
            UISegmentedControl.appearance().setTitleTextAttributes([.font: seg], for: .normal)
        }
        if let tab = UIFont(name: "DMSans-Medium", size: 11) {
            UITabBarItem.appearance().setTitleTextAttributes([.font: tab], for: .normal)
        }
        if let bar = UIFont(name: "DMSans-Medium", size: 17) {
            UIBarButtonItem.appearance().setTitleTextAttributes([.font: bar], for: .normal)
        }
    }
}

extension Color {
    /// "#RRGGBB" for persisting user-picked colors.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

extension ChallengeCategory {
    var tint: Color { Color(hex: defaultHex) }
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
    var background: Color = Theme.primary
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.headline, weight: .semibold))
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
    var tint: Color = Theme.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.headline, weight: .semibold))
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
                    Capsule().fill(i <= step ? Theme.primary : Color.secondary.opacity(0.25))
                        .frame(width: i == step ? 28 : 14, height: 6)
                }
            }
            Text(title).font(.display(.largeTitle, weight: .heavy))
            Text(subtitle).font(.app(.body)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
