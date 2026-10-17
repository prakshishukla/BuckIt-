import SwiftUI

struct GroupsView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.myGroups) { GroupRow(group: $0) }
                Button {
                    showCreate = true
                } label: {
                    Label("Create group", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("My Groups")
        .sheet(isPresented: $showCreate) { CreateGroupView() }
    }
}

struct GroupRow: View {
    @Environment(AppStore.self) private var store
    let group: BuckGroup

    var body: some View {
        let members = group.memberIDs.compactMap { store.user($0) }
        let done = group.challengeIDs.filter { store.myPost(for: $0) != nil }.count

        HStack(spacing: 12) {
            Text(group.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Theme.water.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name).font(.rounded(.headline))
                Text("\(group.listName) · \(done)/\(group.challengeIDs.count) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            AvatarStack(users: members, size: 26, maxCount: 3)
        }
        .card(padding: 12)
    }
}

struct CreateGroupView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🏕️"
    @State private var members: Set<UUID> = []
    @State private var starter: StarterList = .seattle2026

    private static let emojis = ["🏕️", "🌊", "🥾", "🚲", "⛴️", "🌲", "☀️", "🍦", "🛶", "🏔️"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Ferry Friends", text: $name)
                }
                Section("Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.emojis, id: \.self) { option in
                                Button {
                                    emoji = option
                                } label: {
                                    Text(option)
                                        .font(.title)
                                        .frame(width: 48, height: 48)
                                        .background(emoji == option ? Theme.water.opacity(0.2) : .clear, in: Circle())
                                        .overlay(Circle().stroke(emoji == option ? Theme.water : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Friends") {
                    ForEach(store.onBuckItFriends) { friend in
                        let selected = members.contains(friend.id)
                        Button {
                            if selected { members.remove(friend.id) } else { members.insert(friend.id) }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(user: friend, size: 34)
                                Text(friend.fullName).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? Theme.water : .secondary)
                            }
                        }
                    }
                }
                Section("Starter list") {
                    Picker("Starter list", selection: $starter) {
                        ForEach(StarterList.allCases) { list in
                            VStack(alignment: .leading) {
                                Text(list.title)
                                Text(list.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(list)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.createGroup(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji,
                                          memberIDs: Array(members), starter: starter)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
