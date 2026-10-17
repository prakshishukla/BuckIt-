import SwiftUI

/// Another person's profile. You only see lists you're both on, and up to three things they've done on each.
struct FriendProfileView: View {
    @Environment(AppStore.self) private var store
    let friendID: UUID

    var body: some View {
        if let friend = store.user(friendID) {
            content(friend)
        } else {
            EmptyStateView(symbol: "person.crop.circle.badge.questionmark", title: "Profile not found")
        }
    }

    private func content(_ friend: User) -> some View {
        let lists = store.mutualLists(with: friend.id)

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    AvatarView(user: friend, size: 84)
                    Text(friend.fullName).font(.display(.title, weight: .heavy)).foregroundStyle(Theme.plum)
                    Text(lists.isEmpty ? "No lists in common yet"
                                       : "\(lists.count) \(lists.count == 1 ? "list" : "lists") in common")
                        .font(.app(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                if lists.isEmpty {
                    EmptyStateView(symbol: "list.bullet.rectangle", title: "Nothing shared yet",
                                   message: "Add \(friend.firstName) to one of your lists to see what they've done.")
                } else {
                    ForEach(lists) { list in
                        MutualListCard(list: list, friend: friend)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(friend.firstName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MutualListCard: View {
    @Environment(AppStore.self) private var store
    let list: BuckList
    let friend: User

    var body: some View {
        let done = store.challenges(in: list).filter { store.hasDone(friend.id, $0.id) }

        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: ListRoute(id: list.id)) {
                HStack(spacing: 10) {
                    Text(list.emoji).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.name).font(.display(.headline)).foregroundStyle(Theme.plum)
                        Text("\(friend.firstName) has done \(done.count) of \(list.challengeIDs.count)")
                            .font(.app(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("See all")
                        .font(.app(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                    Image(systemName: "chevron.right")
                        .font(.app(.caption, weight: .bold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .buttonStyle(.plain)

            if done.isEmpty {
                Text("\(friend.firstName) hasn't checked anything off here yet.")
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(done.prefix(3)) { item in
                        NavigationLink(value: item) {
                            DoneTile(item: item, photo: store.latestPost(by: friend.id, for: item.id)?.photoFilename)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(0..<max(0, 3 - done.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .card()
    }
}

/// Small photo tile for something a friend has done.
private struct DoneTile: View {
    let item: Challenge
    let photo: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.secondary.opacity(0.1)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image = PhotoStore.image(photo) ?? item.imageName.flatMap({ UIImage(named: $0) }) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: item.iconSymbol).font(.title2).foregroundStyle(item.tint)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Theme.teal)
                        .font(.app(.body, weight: .bold))
                        .padding(5)
                }
            Text(item.title)
                .font(.app(.caption, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
