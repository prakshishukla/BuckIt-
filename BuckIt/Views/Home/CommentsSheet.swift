import SwiftUI

struct CommentsSheet: View {
    @Environment(AppStore.self) private var store
    let postID: UUID
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let comments = store.state.posts.first { $0.id == postID }?.comments ?? []

        NavigationStack {
            Group {
                if comments.isEmpty {
                    EmptyStateView(symbol: "bubble.left.and.bubble.right", title: "No comments yet",
                                   message: "Be the first to hype this up.")
                        .frame(maxHeight: .infinity)
                } else {
                    List(comments) { comment in
                        let author = store.user(comment.userID)
                        HStack(alignment: .top, spacing: 10) {
                            AvatarView(user: author, size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(author?.firstName ?? "Someone").font(.app(.subheadline, weight: .bold))
                                    Text(comment.date.formatted(.relative(presentation: .named)))
                                        .font(.app(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Text(comment.text).font(.app(.subheadline))
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    TextField("Add a comment…", text: $text)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill").font(.app(.title))
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Send")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func send() {
        withAnimation { store.addComment(text, postID: postID) }
        text = ""
    }
}
