import SwiftUI

/// Two dropdowns: time commitment and activity type.
struct ChallengeFilterBar: View {
    @Binding var commitment: Commitment?
    @Binding var category: ChallengeCategory?
    /// Always the full set, so the dropdown is identical on Sponsored and My Lists.
    var categories: [ChallengeCategory] = ChallengeCategory.allCases

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Time commitment", selection: $commitment) {
                    Label("Any time", systemImage: "clock").tag(Commitment?.none)
                    ForEach(Commitment.allCases) { c in
                        Label("\(c.label) · \(c.detail)", systemImage: c.symbol).tag(Optional(c))
                    }
                }
            } label: {
                DropdownLabel(title: commitment.map { "\($0.label) time" } ?? "Time commitment",
                              symbol: commitment?.symbol ?? "clock", isActive: commitment != nil)
            }

            Menu {
                Picker("Activity type", selection: $category) {
                    Label("All activities", systemImage: "square.grid.2x2").tag(ChallengeCategory?.none)
                    ForEach(categories) { cat in
                        Label(cat.label, systemImage: cat.symbol).tag(Optional(cat))
                    }
                }
            } label: {
                DropdownLabel(title: category?.label ?? "Activity type",
                              symbol: category?.symbol ?? "figure.walk", isActive: category != nil)
            }
        }
        .sensoryFeedback(.selection, trigger: commitment)
        .sensoryFeedback(.selection, trigger: category)
    }
}

private struct DropdownLabel: View {
    let title: String
    let symbol: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.app(.caption, weight: .bold))
            Text(title).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 2)
            Image(systemName: "chevron.down").font(.app(.caption2, weight: .bold))
        }
        .font(.app(.footnote, weight: .semibold))
        .foregroundStyle(isActive ? Color.white : Theme.plum)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.card))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isActive ? Color.clear : Theme.lavender.opacity(0.6), lineWidth: 1)
        }
        .animation(.snappy, value: isActive)
    }
}
