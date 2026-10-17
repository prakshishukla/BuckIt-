import SwiftUI

/// Onboarding step 2: fake contact sync, add friends on BuckIt, invite the rest.
struct InviteFriendsView: View {
    @Environment(AppStore.self) private var store
    @State private var groupName = SeedData.crewGroupName
    @State private var composeFor: User?
    @State private var toast: String?
    @State private var addTaps = 0

    var body: some View {
        List {
            Section {
                StepHeader(step: 2, total: 2, title: "Sync your contacts",
                           subtitle: "Find friends already on BuckIt and invite the rest of your crew.")
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                if !store.state.contactsSynced {
                    Button {
                        withAnimation(.spring) { store.syncContacts() }
                    } label: {
                        Label("Allow access", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .listRowBackground(Color.clear)

            if store.state.contactsSynced {
                Section("On BuckIt") {
                    ForEach(store.onBuckItFriends) { friend in
                        ContactRow(user: friend, subtitle: "On BuckIt") {
                            let added = store.isAdded(friend.id)
                            Button {
                                addTaps += 1
                                withAnimation(.snappy) { store.toggleAdded(friend.id) }
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
                    ForEach(store.inviteFriends) { friend in
                        ContactRow(user: friend, subtitle: friend.phone ?? "") {
                            let invited = store.state.invitedIDs.contains(friend.id)
                            Button {
                                invite(friend)
                            } label: {
                                Label(invited ? "Invited" : "Invite", systemImage: invited ? "checkmark" : "message.fill")
                                    .font(.app(.subheadline, weight: .bold))
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 12)
                                    .foregroundStyle(Theme.primary)
                                    .background(Theme.primary.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Invite to BuckIt")
                } footer: {
                    ShareLink(item: SeedData.inviteURL, message: Text(SeedData.inviteMessage)) {
                        Label("Share invite link", systemImage: "square.and.arrow.up")
                            .font(.app(.subheadline, weight: .semibold))
                    }
                    .padding(.top, 6)
                }
            }

            Section("Name your group") {
                TextField("Group name", text: $groupName)
                    .font(.display(.body, weight: .semibold))
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button("Done") { store.finishOnboarding(groupName: groupName) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: addTaps)
        .sheet(item: $composeFor) { friend in
            MessageComposer(recipients: [friend.phone ?? ""], body: SeedData.inviteMessage) { composeFor = nil }
                .ignoresSafeArea()
        }
        .toast($toast)
    }

    private func invite(_ friend: User) {
        store.markInvited(friend.id)
        if MessageComposer.canSend {
            composeFor = friend
        } else {
            // Simulator: no Messages, so copy the link instead.
            UIPasteboard.general.string = SeedData.inviteMessage
            toast = "Invite link copied for \(friend.firstName)"
        }
    }
}

private struct ContactRow<Trailing: View>: View {
    let user: User
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(user: user, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName).font(.app(.headline))
                Text(subtitle).font(.app(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 2)
    }
}
