import SwiftUI

/// Review the shot, pick the list + item (when opened from the Home camera), edit location / tags / caption, then post.
struct CapturePreviewView: View {
    @Environment(AppStore.self) private var store
    /// Set when the capture started from an item; nil means the user picks one here.
    let fixedChallenge: Challenge?
    let photo: UIImage
    /// Shown before the proof photo (e.g. Visa's airplane tickets); not sent to Gemini.
    var covers: [UIImage] = []
    let selfie: UIImage?
    let capturedAt: Date
    @Binding var listID: UUID?
    @Binding var challengeID: String?
    @Binding var locationName: String
    @Binding var tagged: Set<UUID>
    @Binding var caption: String
    var onRetake: () -> Void
    var onPost: () -> Void

    @State private var showTagSheet = false
    @State private var editingLocation = false
    @State private var draftLocation = ""
    @State private var postTaps = 0

    var body: some View {
        let taggedUsers = store.state.friends.filter { tagged.contains($0.id) }
        let challenge = fixedChallenge ?? challengeID.flatMap { store.challenge($0) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PhotoGalleryView(covers: covers, main: photo, selfie: selfie)

                    if fixedChallenge == nil {
                        itemPicker
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Button {
                                draftLocation = locationName
                                editingLocation = true
                            } label: {
                                ChipView(text: locationName, symbol: "mappin.and.ellipse")
                            }
                            .accessibilityLabel("Location: \(locationName). Tap to edit.")
                            ChipView(text: capturedAt.formatted(date: .omitted, time: .shortened), symbol: "clock",
                                     tint: Theme.teal)
                                .accessibilityLabel("Taken at \(capturedAt.formatted(date: .omitted, time: .shortened))")
                        }
                        Button {
                            showTagSheet = true
                        } label: {
                            ChipView(text: taggedUsers.isEmpty ? "Tag friends" : "With " + taggedUsers.map(\.firstName).formatted(.list(type: .and)),
                                     symbol: "person.2.fill", isSelected: !taggedUsers.isEmpty, tint: Theme.plum)
                        }
                    }
                    .buttonStyle(.plain)

                    TextField("Add a caption…", text: $caption, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let challenge, challenge.isSponsored, let reward = challenge.reward {
                        Label("Sponsored by \(challenge.sponsor?.name ?? "a brand"): posting unlocks \(reward.headline).",
                              systemImage: "gift.fill")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(challenge?.title ?? "New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Retake", action: onRetake)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    postTaps += 1
                    onPost()
                } label: {
                    Label("Post", systemImage: "paperplane.fill")
                }
                .disabled(challenge == nil)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: postTaps)
            .sheet(isPresented: $showTagSheet) {
                TagFriendsSheet(selection: $tagged)
            }
            .alert("Location", isPresented: $editingLocation) {
                TextField("Where was this?", text: $draftLocation)
                Button("Save") {
                    let trimmed = draftLocation.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { locationName = trimmed }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

extension CapturePreviewView {
    /// "What did you do?" — choose a list, then an item on it.
    var itemPicker: some View {
        let lists = store.myLists
        let list = listID.flatMap { store.list($0) }
        let items = list.map { store.challenges(in: $0) } ?? []
        let open = items.filter { store.myPost(for: $0.id) == nil }
        let done = items.filter { store.myPost(for: $0.id) != nil }
        let chosen = challengeID.flatMap { store.challenge($0) }

        return VStack(alignment: .leading, spacing: 10) {
            Text("What did you do?").font(.display(.headline)).foregroundStyle(Theme.plum)

            Menu {
                ForEach(lists) { option in
                    Button {
                        listID = option.id
                        if let id = challengeID, !option.challengeIDs.contains(id) { challengeID = nil }
                    } label: {
                        Label("\(option.emoji) \(option.name)", systemImage: listID == option.id ? "checkmark" : "list.bullet")
                    }
                }
            } label: {
                PickerRow(title: "List", value: list.map { "\($0.emoji) \($0.name)" } ?? "Choose a list", isSet: list != nil)
            }

            Menu {
                if !open.isEmpty {
                    Section("To do") {
                        ForEach(open) { item in
                            Button { challengeID = item.id } label: {
                                Label(item.title, systemImage: challengeID == item.id ? "checkmark" : item.iconSymbol)
                            }
                        }
                    }
                }
                if !done.isEmpty {
                    Section("Done before") {
                        ForEach(done) { item in
                            Button { challengeID = item.id } label: {
                                Label(item.title, systemImage: challengeID == item.id ? "checkmark" : "checkmark.circle")
                            }
                        }
                    }
                }
            } label: {
                PickerRow(title: "Item", value: chosen?.title ?? (list == nil ? "Pick a list first" : "Choose an item"), isSet: chosen != nil)
            }
            .disabled(list == nil)
        }
        .card(padding: 14)
    }
}

private struct PickerRow: View {
    let title: String
    let value: String
    let isSet: Bool

    var body: some View {
        HStack {
            Text(title).font(.app(.subheadline, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.app(.subheadline, weight: isSet ? .semibold : .regular))
                .foregroundStyle(isSet ? Theme.plum : .secondary)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down").font(.app(.caption)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TagFriendsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<UUID>

    var body: some View {
        NavigationStack {
            List(store.taggableFriends) { friend in
                let selected = selection.contains(friend.id)
                Button {
                    if selected { selection.remove(friend.id) } else { selection.insert(friend.id) }
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(user: friend, size: 38)
                        Text(friend.fullName).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.app(.title3))
                            .foregroundStyle(selected ? Theme.primary : .secondary)
                    }
                }
                .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
            }
            .navigationTitle("Tag friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
        .presentationDetents([.medium, .large])
    }
}
