import SwiftUI

/// Review the shot, edit location / tags / caption, then post.
struct CapturePreviewView: View {
    @Environment(AppStore.self) private var store
    let challenge: Challenge
    let photo: UIImage
    let selfie: UIImage?
    let capturedAt: Date
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

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DualPhotoView(main: photo, selfie: selfie)

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

                    if challenge.isSponsored {
                        Label("This is a sponsored challenge. Your photo will be checked against \(challenge.criteria.count) criteria to unlock the reward.",
                              systemImage: "sparkles")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(challenge.title)
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
