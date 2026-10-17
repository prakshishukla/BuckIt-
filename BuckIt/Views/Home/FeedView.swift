import SwiftUI

struct FeedView: View {
    @Environment(AppStore.self) private var store
    @State private var groupFilter: UUID?

    var body: some View {
        let posts = store.feedPosts(groupID: groupFilter)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.myGroups.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "All groups", isSelected: groupFilter == nil) { groupFilter = nil }
                                ForEach(store.myGroups) { group in
                                    FilterChip(title: "\(group.emoji) \(group.name)", isSelected: groupFilter == group.id) {
                                        groupFilter = group.id
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if posts.isEmpty {
                        EmptyStateView(showsBucket: true,
                                       title: "Nothing here yet — go complete a challenge!",
                                       message: "When you or your crew finish something on the list, it shows up here.",
                                       actionTitle: "Browse challenges") {
                            store.selectedTab = .challenges
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 18) {
                            ForEach(posts) { post in
                                PostCardView(post: post)
                                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                            removal: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
                .animation(.spring(duration: 0.5), value: posts.map(\.id))
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("BuckIt")
        }
    }
}
