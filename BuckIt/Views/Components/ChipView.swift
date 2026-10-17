import SwiftUI

struct ChipView: View {
    var text: String
    var symbol: String? = nil
    var isSelected = false
    var tint: Color = Theme.primary
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text).lineLimit(1)
        }
        .font(compact ? .app(.caption, weight: .semibold) : .app(.subheadline, weight: .semibold))
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 7)
        .foregroundStyle(isSelected ? Color.white : tint)
        .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.13)), in: Capsule())
    }
}

extension ChipView {
    static func commitment(_ c: Commitment, compact: Bool = true) -> ChipView {
        ChipView(text: compact ? c.label : "\(c.label) · \(c.detail)", symbol: c.symbol, tint: Theme.teal, compact: compact)
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

/// Lays children out left to right, wrapping onto new lines (centered).
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let addition = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += addition
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
