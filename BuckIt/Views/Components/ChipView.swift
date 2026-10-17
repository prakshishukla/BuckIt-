import SwiftUI

struct ChipView: View {
    var text: String
    var symbol: String? = nil
    var isSelected = false
    var tint: Color = Theme.water
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text).lineLimit(1)
        }
        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 7)
        .foregroundStyle(isSelected ? Color.white : tint)
        .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.13)), in: Capsule())
    }
}

extension ChipView {
    static func commitment(_ c: Commitment, compact: Bool = true) -> ChipView {
        ChipView(text: "\(c.label) · \(c.detail)", symbol: c.symbol, tint: Theme.evergreen, compact: compact)
    }
}

/// Generic "label + selectable chip" used by filter rows.
struct FilterChip: View {
    let title: String
    var symbol: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChipView(text: title, symbol: symbol, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
    }
}
