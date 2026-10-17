import SwiftUI

struct ChallengesView: View {
    enum ListTab: String, CaseIterable, Identifiable {
        case sponsored = "Sponsored"
        case lists = "My Lists"
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
                    case .lists: listsList
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
            .navigationDestination(for: ListRoute.self) { route in
                ListDetailView(listID: route.id, mode: .challenges, zoom: zoom)
            }
            .navigationDestination(for: FriendRoute.self) { route in
                FriendProfileView(friendID: route.id)
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

        ChallengeFilterBar(commitment: $commitmentFilter, category: $categoryFilter)

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

    // MARK: - My Lists (only lists I'm on; tap one to see what's left)

    @ViewBuilder
    private var listsList: some View {
        // Lists I've finished live under Profile → Completed lists, not here.
        if store.activeLists.isEmpty {
            EmptyStateView(symbol: "list.bullet", title: store.myLists.isEmpty ? "No lists yet" : "All your lists are done! 🎉",
                           message: store.myLists.isEmpty ? "Create a list from your Profile and add people to it."
                                                          : "Find them under Profile → Completed lists, or start a new one.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.activeLists) { list in
                    NavigationLink(value: ListRoute(id: list.id)) {
                        ListCard(list: list)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// List tile on the My Lists tab.
private struct ListCard: View {
    @Environment(AppStore.self) private var store
    let list: BuckList

    var body: some View {
        let left = list.challengeIDs.filter { store.myPost(for: $0) == nil }.count
        let done = list.challengeIDs.count - left

        HStack(spacing: 14) {
            Text(list.emoji)
                .font(.system(size: 32))
                .frame(width: 64, height: 64)
                .background(Theme.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(list.name)
                    .font(.display(.title3))
                    .foregroundStyle(Theme.plum)
                HStack(spacing: 8) {
                    AvatarStack(users: store.members(of: list), size: 22, maxCount: 4)
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
