import SwiftUI

struct FeedView: View {
    @Environment(AppStore.self) private var store
    @State private var listFilter: UUID?

    var body: some View {
        let posts = store.feedPosts(listID: listFilter)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.myLists.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "All lists", isSelected: listFilter == nil) { listFilter = nil }
                                ForEach(store.myLists) { list in
                                    FilterChip(title: "\(list.emoji) \(list.name)", isSelected: listFilter == list.id) {
                                        listFilter = list.id
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if posts.isEmpty {
                        EmptyStateView(showsBucket: true,
                                       title: "Nothing here yet — go complete a challenge!",
                                       message: "When you or your friends finish something on a list, it shows up here.",
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.startCapture()
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.app(.headline, weight: .semibold))
                    }
                    .accessibilityLabel("Take a photo")
                }
            }
            .navigationDestination(for: FriendRoute.self) { FriendProfileView(friendID: $0.id) }
            .navigationDestination(for: ListRoute.self) { ListDetailView(listID: $0.id, mode: .profile) }
            .navigationDestination(for: Challenge.self) { ChallengeDetailView(challenge: $0) }
        }
    }
}
