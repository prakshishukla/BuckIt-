import SwiftUI

/// A bucket list.
/// - `.profile`: everything on the list (completed items at the bottom), the members, "+" to add items.
/// - `.challenges`: only what's left to do, with filters.
struct ListDetailView: View {
    enum Mode { case profile, challenges }

    @Environment(AppStore.self) private var store
    let listID: UUID
    let mode: Mode
    var zoom: Namespace.ID? = nil

    @State private var showAddItems = false
    @State private var showAddMembers = false
    @State private var commitmentFilter: Commitment?
    @State private var categoryFilter: ChallengeCategory?

    var body: some View {
        if let list = store.list(listID) {
            content(list)
        } else {
            EmptyStateView(symbol: "list.bullet", title: "List not found")
        }
    }

    private func content(_ list: BuckList) -> some View {
        let all = store.challenges(in: list)
        let filtered = all.filter { c in
            (commitmentFilter == nil || c.commitment == commitmentFilter) && (categoryFilter == nil || c.category == categoryFilter)
        }
        let open = filtered.filter { store.myPost(for: $0.id) == nil }
        let done = filtered.filter { store.myPost(for: $0.id) != nil }
        let doneCount = all.filter { store.myPost(for: $0.id) != nil }.count

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(list, done: doneCount, total: all.count)

                if mode == .profile {
                    membersSection(list)
                }

                ChallengeFilterBar(commitment: $commitmentFilter, category: $categoryFilter)

                if all.isEmpty {
                    EmptyStateView(symbol: "plus.circle", title: "Nothing on this list yet",
                                   message: "Add Seattle favorites, sponsored challenges, or your own ideas.",
                                   actionTitle: mode == .profile ? "Add items" : nil) { showAddItems = true }
                } else if open.isEmpty && (mode == .challenges || done.isEmpty) {
                    if commitmentFilter != nil || categoryFilter != nil {
                        EmptyStateView(symbol: "line.3.horizontal.decrease.circle", title: "No matches",
                                       message: "Try a different time or activity.", actionTitle: "Clear filters") {
                            commitmentFilter = nil
                            categoryFilter = nil
                        }
                    } else {
                        EmptyStateView(showsBucket: true, title: "Every item done! 🎉",
                                       message: "This list is complete. Add more from your Profile.")
                    }
                }

                // Open items, by section
                ForEach(SeedData.sectionOrder, id: \.self) { section in
                    let items = open.filter { ($0.section ?? "Sponsored picks") == section }
                    if !items.isEmpty {
                        itemSection(section, items: items, list: list)
                    }
                }

                // Profile shows completed items too, at the bottom.
                if mode == .profile, !done.isEmpty {
                    itemSection("Completed", items: done, list: list)
                }
            }
            .padding(16)
            .animation(.snappy, value: open.map(\.id))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .profile {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItems = true
                    } label: {
                        Image(systemName: "plus").font(.app(.headline, weight: .bold))
                    }
                    .accessibilityLabel("Add items to list")
                }
            }
        }
        .sheet(isPresented: $showAddItems) { AddItemSheet(listID: list.id) }
        .sheet(isPresented: $showAddMembers) { AddMembersSheet(listID: list.id) }
    }

    private func itemSection(_ title: String, items: [Challenge], list: BuckList) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.display(.title3)).foregroundStyle(Theme.plum)
                if title == "Completed" {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.teal)
                }
            }
            ForEach(items) { challenge in
                NavigationLink(value: challenge) {
                    ChallengeCardView(challenge: challenge, completers: store.completers(of: challenge.id, in: list))
                }
                .buttonStyle(.plain)
                .modifier(OptionalZoomSource(id: challenge.id, namespace: zoom))
                .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.9).combined(with: .opacity)))
            }
        }
    }

    private func header(_ list: BuckList, done: Int, total: Int) -> some View {
        HStack(spacing: 14) {
            Text(list.emoji)
                .font(.system(size: 34))
                .frame(width: 64, height: 64)
                .background(Theme.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(.display(.title2, weight: .heavy))
                    .foregroundStyle(Theme.plum)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Theme.teal)
                Text(store.isCompleted(list) ? "You finished this list 🎉 · \(list.memberIDs.count) \(list.memberIDs.count == 1 ? "person" : "people")"
                                             : "\(done) of \(total) done · \(list.memberIDs.count) \(list.memberIDs.count == 1 ? "person" : "people")")
                    .font(.app(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func membersSection(_ list: BuckList) -> some View {
        let members = store.members(of: list)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members").font(.display(.title3)).foregroundStyle(Theme.plum)
                Text("\(members.count)").font(.app(.subheadline, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddMembers = true
                } label: {
                    Label("Add people", systemImage: "person.badge.plus")
                        .font(.app(.subheadline, weight: .semibold))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(members) { member in
                        MemberChip(user: member, isMe: member.id == store.me.id,
                                   progress: "\(store.progress(of: member.id, in: list))/\(list.challengeIDs.count)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .card()
    }
}

/// Avatar + name; tapping a friend opens their profile.
private struct MemberChip: View {
    let user: User
    let isMe: Bool
    /// "4/6" items done, so you can follow everyone's progress (even on lists you've finished).
    let progress: String

    var body: some View {
        let chip = VStack(spacing: 4) {
            AvatarView(user: user, size: 52)
            Text(isMe ? "You" : user.firstName)
                .font(.app(.caption, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(progress)
                .font(.app(.caption2, weight: .semibold))
                .foregroundStyle(Theme.teal)
        }
        .frame(width: 60)

        if isMe {
            chip
        } else {
            NavigationLink(value: FriendRoute(id: user.id)) { chip }
                .buttonStyle(.plain)
                .accessibilityHint("Opens \(user.firstName)'s profile")
        }
    }
}

/// Applies the iOS 18 zoom source only when a namespace was provided.
struct OptionalZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.zoomSource(id: id, in: namespace)
        } else {
            content
        }
    }
}
