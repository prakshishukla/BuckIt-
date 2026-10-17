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

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.challengesPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("List", selection: $tab) {
                        ForEach(ListTab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .sponsored: sponsoredList
                    case .groups: groupsList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Challenges")
            .navigationDestination(for: Challenge.self) { challenge in
                ChallengeDetailView(challenge: challenge)
                    .zoomDestination(id: challenge.id, in: zoom)
            }
            .navigationDestination(for: GroupRoute.self) { route in
                GroupDetailView(groupID: route.id, mode: .challenges, zoom: zoom)
            }
        }
    }

    // MARK: - Sponsored

    @ViewBuilder
    private var sponsoredList: some View {
        let all = SeedData.sponsoredChallenges
        // Completed challenges drop off the list.
        let open = all.filter { store.myPost(for: $0.id) == nil }
        let items = open.filter { c in
            (commitmentFilter == nil || c.commitment == commitmentFilter) && (categoryFilter == nil || c.category == categoryFilter)
        }

        ChallengeFilterBar(commitment: $commitmentFilter, category: $categoryFilter,
                           categories: ChallengeCategory.allCases.filter { cat in all.contains { $0.category == cat } })

        if open.isEmpty {
            EmptyStateView(symbol: "gift", title: "You've done them all! 🎉",
                           message: "Check your Wallet for your rewards.")
        } else if items.isEmpty {
            EmptyStateView(symbol: "line.3.horizontal.decrease.circle", title: "No matches",
                           message: "Try a different time or activity.", actionTitle: "Clear filters") {
                commitmentFilter = nil
                categoryFilter = nil
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { challenge in
                    NavigationLink(value: challenge) {
                        ChallengeCardView(challenge: challenge)
                    }
                    .buttonStyle(.plain)
                    .zoomSource(id: challenge.id, in: zoom)
                }
            }
            .animation(.snappy, value: items.map(\.id))
        }
    }

    // MARK: - My Groups (only groups I'm in; tap one to see its list)

    @ViewBuilder
    private var groupsList: some View {
        if store.myGroups.isEmpty {
            EmptyStateView(symbol: "person.3.fill", title: "No groups yet",
                           message: "Create a group from your Profile to start a shared bucket list.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.myGroups) { group in
                    NavigationLink(value: GroupRoute(id: group.id)) {
                        GroupCard(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Group tile on the My Groups tab.
private struct GroupCard: View {
    @Environment(AppStore.self) private var store
    let group: BuckGroup

    var body: some View {
        let left = group.challengeIDs.filter { store.myPost(for: $0) == nil }.count
        let done = group.challengeIDs.count - left

        HStack(spacing: 14) {
            Text(group.emoji)
                .font(.system(size: 32))
                .frame(width: 64, height: 64)
                .background(Theme.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(group.name)
                    .font(.display(.title3))
                    .foregroundStyle(Theme.plum)
                Text(group.listName)
                    .font(.app(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    AvatarStack(users: store.members(of: group), size: 22, maxCount: 4)
                    Text("\(left) to go · \(done) done")
                        .font(.app(.caption, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .card(padding: 14)
        .contentShape(Rectangle())
    }
}
