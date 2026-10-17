import SwiftUI

/// A group's bucket list.
/// - `.profile`: the entire list (done items included), the members, and a "+" to add people.
/// - `.challenges`: only what's left to do, with filters.
struct GroupDetailView: View {
    enum Mode { case profile, challenges }

    @Environment(AppStore.self) private var store
    let groupID: UUID
    let mode: Mode
    var zoom: Namespace.ID? = nil

    @State private var showAddMembers = false
    @State private var commitmentFilter: Commitment?
    @State private var categoryFilter: ChallengeCategory?

    static let sectionOrder = ["Sponsored picks", "Local", "Parks & Adventures"]

    var body: some View {
        if let group = store.group(groupID) {
            content(group)
        } else {
            EmptyStateView(symbol: "person.3", title: "Group not found")
        }
    }

    private func content(_ group: BuckGroup) -> some View {
        let all = group.challengeIDs.compactMap(SeedData.challenge)
        let done = all.filter { store.myPost(for: $0.id) != nil }
        let visible = all.filter { challenge in
            (mode == .profile || store.myPost(for: challenge.id) == nil)
                && (commitmentFilter == nil || challenge.commitment == commitmentFilter)
                && (categoryFilter == nil || challenge.category == categoryFilter)
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(group, done: done.count, total: all.count)

                if mode == .profile {
                    membersSection(group)
                } else {
                    ChallengeFilterBar(commitment: $commitmentFilter, category: $categoryFilter,
                                       categories: ChallengeCategory.allCases.filter { cat in all.contains { $0.category == cat } })
                }

                if visible.isEmpty {
                    if commitmentFilter != nil || categoryFilter != nil {
                        EmptyStateView(symbol: "line.3.horizontal.decrease.circle", title: "No matches",
                                       message: "Try a different time or activity.", actionTitle: "Clear filters") {
                            commitmentFilter = nil
                            categoryFilter = nil
                        }
                    } else {
                        EmptyStateView(showsBucket: true, title: "Every task done! 🎉",
                                       message: "This list is complete. Time to start a new one.")
                    }
                }

                ForEach(Self.sectionOrder, id: \.self) { section in
                    let items = visible.filter { ($0.section ?? "Sponsored picks") == section }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section)
                                .font(.display(.title3))
                                .foregroundStyle(Theme.plum)
                            ForEach(items) { challenge in
                                NavigationLink(value: challenge) {
                                    ChallengeCardView(challenge: challenge,
                                                      completers: store.completers(of: challenge.id, in: group))
                                }
                                .buttonStyle(.plain)
                                .modifier(OptionalZoomSource(id: challenge.id, namespace: zoom))
                                .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.9).combined(with: .opacity)))
                            }
                        }
                    }
                }
            }
            .padding(16)
            .animation(.snappy, value: visible.map(\.id))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .profile {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMembers = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.app(.headline, weight: .bold))
                    }
                    .accessibilityLabel("Add people")
                }
            }
        }
        .sheet(isPresented: $showAddMembers) {
            AddMembersSheet(groupID: group.id)
        }
    }

    private func header(_ group: BuckGroup, done: Int, total: Int) -> some View {
        HStack(spacing: 14) {
            Text(group.emoji)
                .font(.system(size: 34))
                .frame(width: 64, height: 64)
                .background(Theme.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(group.listName)
                    .font(.display(.title2, weight: .heavy))
                    .foregroundStyle(Theme.plum)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Theme.teal)
                Text("\(done) of \(total) done · \(group.memberIDs.count) members")
                    .font(.app(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func membersSection(_ group: BuckGroup) -> some View {
        let members = store.members(of: group)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members").font(.display(.title3)).foregroundStyle(Theme.plum)
                Text("\(members.count)")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddMembers = true
                } label: {
                    Label("Add", systemImage: "person.badge.plus")
                        .font(.app(.subheadline, weight: .semibold))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(members) { member in
                        VStack(spacing: 6) {
                            AvatarView(user: member, size: 52)
                            Text(member.id == store.me.id ? "You" : member.firstName)
                                .font(.app(.caption, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .card()
    }
}

/// Applies the iOS 18 zoom source only when a namespace was provided.
private struct OptionalZoomSource: ViewModifier {
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

/// "+" sheet: add friends on BuckIt to the group, or share an invite link.
struct AddMembersSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    @State private var taps = 0

    var body: some View {
        let memberIDs = Set(store.group(groupID)?.memberIDs ?? [])

        NavigationStack {
            List {
                Section("Friends on BuckIt") {
                    ForEach(store.onBuckItFriends) { friend in
                        let added = memberIDs.contains(friend.id)
                        HStack(spacing: 12) {
                            AvatarView(user: friend, size: 40)
                            Text(friend.fullName).font(.app(.body, weight: .medium))
                            Spacer()
                            Button {
                                taps += 1
                                withAnimation(.snappy) { store.toggleMember(friend.id, in: groupID) }
                            } label: {
                                Text(added ? "Added ✓" : "Add")
                                    .font(.app(.subheadline, weight: .bold))
                                    .frame(minWidth: 64)
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 12)
                                    .foregroundStyle(added ? Theme.teal : .white)
                                    .background(added ? AnyShapeStyle(Theme.teal.opacity(0.14)) : AnyShapeStyle(Theme.primary),
                                                in: Capsule())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Section {
                    ShareLink(item: SeedData.inviteURL, message: Text(SeedData.inviteMessage)) {
                        Label("Invite someone new", systemImage: "square.and.arrow.up")
                            .font(.app(.body, weight: .semibold))
                    }
                } footer: {
                    Text("Friends not on BuckIt yet get a link to join.")
                }
            }
            .navigationTitle("Add people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
        }
        .presentationDetents([.medium, .large])
    }
}
