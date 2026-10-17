import SwiftUI

struct ChallengesView: View {
    enum ListTab: String, CaseIterable, Identifiable {
        case sponsored = "Sponsored"
        case groups = "My Groups"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @State private var tab: ListTab = .sponsored
    @State private var commitmentFilter: Commitment?
    @State private var categoryFilter: ChallengeCategory?
    @Namespace private var zoom

    private static let sectionOrder = ["Sponsored picks", "Local", "Parks & Adventures"]

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.challengesPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("List", selection: $tab) {
                        ForEach(ListTab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    filterChips

                    switch tab {
                    case .sponsored: sponsoredList
                    case .groups: groupsList
                    }
                }
                .padding(.vertical, 8)
                .animation(.snappy, value: commitmentFilter)
                .animation(.snappy, value: categoryFilter)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Challenges")
            .navigationDestination(for: Challenge.self) { challenge in
                ChallengeDetailView(challenge: challenge)
                    .zoomDestination(id: challenge.id, in: zoom)
            }
        }
    }

    // MARK: - Filters

    private var tabChallenges: [Challenge] {
        switch tab {
        case .sponsored:
            return SeedData.sponsoredChallenges
        case .groups:
            let ids = store.myGroups.flatMap(\.challengeIDs)
            return ids.compactMap(SeedData.challenge)
        }
    }

    private func passesFilters(_ c: Challenge) -> Bool {
        (commitmentFilter == nil || c.commitment == commitmentFilter) && (categoryFilter == nil || c.category == categoryFilter)
    }

    private var filterChips: some View {
        let categories = ChallengeCategory.allCases.filter { cat in tabChallenges.contains { $0.category == cat } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: commitmentFilter == nil && categoryFilter == nil) {
                    commitmentFilter = nil
                    categoryFilter = nil
                }
                ForEach(Commitment.allCases) { c in
                    FilterChip(title: c.label, symbol: c.symbol, isSelected: commitmentFilter == c) {
                        commitmentFilter = commitmentFilter == c ? nil : c
                    }
                }
                Divider().frame(height: 22)
                ForEach(categories) { cat in
                    FilterChip(title: cat.label, symbol: cat.symbol, isSelected: categoryFilter == cat) {
                        categoryFilter = categoryFilter == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .sensoryFeedback(.selection, trigger: "\(String(describing: commitmentFilter))\(String(describing: categoryFilter))")
    }

    // MARK: - Lists

    @ViewBuilder
    private var sponsoredList: some View {
        let items = SeedData.sponsoredChallenges.filter(passesFilters)
        if items.isEmpty {
            noMatches
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { cardLink($0) }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var groupsList: some View {
        if store.myGroups.isEmpty {
            EmptyStateView(symbol: "person.3.fill", title: "No groups yet",
                           message: "Create a group from your Profile to start a shared bucket list.")
        } else {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(store.myGroups) { group in
                    let items = group.challengeIDs.compactMap(SeedData.challenge).filter(passesFilters)
                    let done = group.challengeIDs.filter { store.myPost(for: $0) != nil }.count
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.listName).font(.rounded(.title2, weight: .heavy))
                            Text("\(group.emoji) \(group.name) · \(done)/\(group.challengeIDs.count) done")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if items.isEmpty {
                            noMatches
                        }
                        ForEach(Self.sectionOrder, id: \.self) { section in
                            let sectionItems = items.filter { ($0.section ?? "Sponsored picks") == section }
                            if !sectionItems.isEmpty {
                                Text(section.uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                ForEach(sectionItems) { cardLink($0) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var noMatches: some View {
        EmptyStateView(symbol: "line.3.horizontal.decrease.circle", title: "No matches",
                       message: "Try a different filter.", actionTitle: "Clear filters") {
            commitmentFilter = nil
            categoryFilter = nil
        }
    }

    private func cardLink(_ challenge: Challenge) -> some View {
        NavigationLink(value: challenge) {
            ChallengeCardView(challenge: challenge)
        }
        .buttonStyle(.plain)
        .zoomSource(id: challenge.id, in: zoom)
    }
}
