import SwiftUI

/// "+" on a list in Profile: add items from the catalog, or write your own.
struct AddItemSheet: View {
    enum Source: String, CaseIterable, Identifiable {
        case catalog = "Browse"
        case custom = "Your own"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let listID: UUID

    @State private var source: Source = .catalog
    @State private var search = ""
    @State private var title = ""
    @State private var details = ""
    @State private var location = ""
    @State private var commitment: Commitment = .low
    @State private var category: ChallengeCategory = .outdoors
    @State private var toast: String?
    @State private var adds = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Source", selection: $source) {
                    ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                switch source {
                case .catalog: catalog
                case .custom: customForm
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add to \(store.list(listID)?.name ?? "list")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .toast($toast)
            .sensoryFeedback(.success, trigger: adds)
        }
    }

    private var catalog: some View {
        let onList = Set(store.list(listID)?.challengeIDs ?? [])
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let available = (SeedData.allChallenges + store.state.customChallenges).filter { c in
            !onList.contains(c.id)
                && (query.isEmpty || c.title.lowercased().contains(query) || (c.sponsor?.name.lowercased().contains(query) ?? false))
        }

        return List {
            if available.isEmpty {
                Text(query.isEmpty ? "Everything in the catalog is already on this list." : "No matches for “\(search)”.")
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
            }
            ForEach(SeedData.sectionOrder, id: \.self) { section in
                let items = available.filter { ($0.section ?? "Sponsored picks") == section }
                if !items.isEmpty {
                    Section(section) {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                ChallengeThumb(challenge: item, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.app(.subheadline, weight: .semibold)).lineLimit(2)
                                    if let sponsor = item.sponsor {
                                        Text("Sponsored · \(sponsor.name)").font(.app(.caption)).foregroundStyle(.secondary)
                                    } else if let location = item.location {
                                        Text(location).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button {
                                    withAnimation(.snappy) { store.addItem(item.id, to: listID) }
                                    adds += 1
                                    toast = "Added “\(item.title)”"
                                } label: {
                                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.primary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Add \(item.title)")
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search items")
    }

    private var customForm: some View {
        Form {
            Section("What's the idea?") {
                TextField("e.g. Watch the sunrise from Kerry Park", text: $title)
                TextField("Details (optional)", text: $details, axis: .vertical).lineLimit(2...4)
                TextField("Where? (optional)", text: $location)
            }
            Section("Time commitment") {
                Picker("Time commitment", selection: $commitment) {
                    ForEach(Commitment.allCases) { c in
                        Label("\(c.label) · \(c.detail)", systemImage: c.symbol).tag(c)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("Activity type") {
                Picker("Activity type", selection: $category) {
                    ForEach(ChallengeCategory.allCases) { cat in
                        Label(cat.label, systemImage: cat.symbol).tag(cat)
                    }
                }
            }
            Section {
                Button {
                    store.addCustomItem(title: title, description: details, location: location,
                                        commitment: commitment, category: category, to: listID)
                    adds += 1
                    toast = "Added “\(title.trimmingCharacters(in: .whitespaces))”"
                    title = ""; details = ""; location = ""
                } label: {
                    Label("Add to list", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// Members "Add people": add friends on BuckIt to the list, or share an invite link.
struct AddMembersSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let listID: UUID
    @State private var taps = 0

    var body: some View {
        let memberIDs = Set(store.list(listID)?.memberIDs ?? [])

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
                                withAnimation(.snappy) { store.toggleMember(friend.id, in: listID) }
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

struct CreateListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🏕️"
    @State private var members: Set<UUID> = []
    @State private var starter: StarterList = .seattleSummer

    private static let emojis = ["🏕️", "🌊", "🥾", "🚲", "⛴️", "🌲", "☀️", "🍦", "🛶", "🏔️", "🎟️", "🍜"]

    var body: some View {
        NavigationStack {
            Form {
                Section("List name") {
                    TextField("e.g. Ferry Friends Summer", text: $name)
                }
                Section("Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.emojis, id: \.self) { option in
                                Button {
                                    emoji = option
                                } label: {
                                    Text(option)
                                        .font(.system(size: 28))
                                        .frame(width: 48, height: 48)
                                        .background(emoji == option ? Theme.primary.opacity(0.2) : .clear, in: Circle())
                                        .overlay(Circle().stroke(emoji == option ? Theme.primary : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("People on this list") {
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
                                    .foregroundStyle(selected ? Theme.primary : .secondary)
                            }
                        }
                    }
                }
                Section("Start with") {
                    Picker("Start with", selection: $starter) {
                        ForEach(StarterList.allCases) { list in
                            VStack(alignment: .leading) {
                                Text(list.title)
                                Text(list.subtitle).font(.app(.caption)).foregroundStyle(.secondary)
                            }
                            .tag(list)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.createList(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji,
                                         memberIDs: Array(members), starter: starter)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Profile → My Lists (full page).
struct ListsView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.activeLists) { list in
                    NavigationLink(value: ListRoute(id: list.id)) { ListRow(list: list) }
                        .buttonStyle(.plain)
                }
                Button {
                    showCreate = true
                } label: {
                    Label("Create list", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
                if !store.completedLists.isEmpty {
                    Text("Completed lists")
                        .font(.display(.title3))
                        .foregroundStyle(Theme.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                    ForEach(store.completedLists) { list in
                        NavigationLink(value: ListRoute(id: list.id)) { ListRow(list: list) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("My Lists")
        .sheet(isPresented: $showCreate) { CreateListView() }
    }
}

struct ListRow: View {
    @Environment(AppStore.self) private var store
    let list: BuckList

    var body: some View {
        let done = list.challengeIDs.filter { store.myPost(for: $0) != nil }.count
        let complete = store.isCompleted(list)

        HStack(spacing: 12) {
            Text(list.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Theme.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name).font(.display(.headline)).foregroundStyle(Theme.plum)
                Text(complete ? "Completed · all \(list.challengeIDs.count) done" : "\(done)/\(list.challengeIDs.count) done")
                    .font(.app(.caption, weight: complete ? .semibold : .regular))
                    .foregroundStyle(complete ? Theme.teal : .secondary)
            }
            Spacer()
            AvatarStack(users: store.members(of: list), size: 26, maxCount: 3)
            Image(systemName: "chevron.right")
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .card(padding: 12)
    }
}

/// Square photo (or icon tile) for an item.
struct ChallengeThumb: View {
    let challenge: Challenge
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            if let name = challenge.imageName, let image = UIImage(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(challenge.tint.gradient)
                Image(systemName: challenge.iconSymbol)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}
