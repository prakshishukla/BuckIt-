import SwiftUI

enum OnboardingStep: Hashable { case invite }

struct OnboardingFlow: View {
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            PreferencesView(mode: .onboarding) { path.append(.invite) }
                .navigationDestination(for: OnboardingStep.self) { _ in InviteFriendsView() }
        }
    }
}

/// Onboarding step 1, also reused from Profile to edit preferences.
struct PreferencesView: View {
    enum Mode { case onboarding, edit }

    let mode: Mode
    var onDone: () -> Void

    @Environment(AppStore.self) private var store
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var city = "Seattle"
    @State private var season: Season = .summer
    @State private var commitment: Commitment = .medium
    @State private var loaded = false

    private static let cities = ["Seattle", "Portland", "San Francisco", "Vancouver"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if mode == .onboarding {
                    StepHeader(step: 1, total: 2, title: "Let's set you up",
                               subtitle: "We'll tailor your bucket list to where you are and when you're exploring.")
                }

                section("Your name") {
                    HStack(spacing: 10) {
                        field("First name", text: $firstName)
                        field("Last name", text: $lastName)
                    }
                }

                section("City") {
                    Menu {
                        ForEach(Self.cities, id: \.self) { option in
                            if option == "Seattle" {
                                Button { city = option } label: {
                                    Label(option, systemImage: city == option ? "checkmark" : "mappin")
                                }
                            } else {
                                Button("\(option) — coming soon") {}.disabled(true)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.primary)
                            Text(city).font(.app(.headline)).foregroundStyle(.primary)
                            Spacer()
                            Text("More cities soon").font(.app(.caption)).foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down").font(.app(.caption)).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                section("Season") {
                    Picker("Season", selection: $season) {
                        ForEach(Season.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .edit {
                    section("Commitment") {
                        HStack(spacing: 10) {
                            ForEach(Commitment.allCases) { option in
                                CommitmentCard(commitment: option, isSelected: commitment == option)
                                    .onTapGesture { withAnimation(.snappy) { commitment = option } }
                            }
                        }
                        .sensoryFeedback(.selection, trigger: commitment)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button(mode == .onboarding ? "Next" : "Save") {
                // Commitment isn't asked during setup; it's only editable later from Profile.
                store.savePreferences(firstName: firstName, lastName: lastName, city: city,
                                      season: season, commitment: mode == .edit ? commitment : nil)
                onDone()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.background.opacity(0.95))
        }
        .navigationTitle(mode == .edit ? "Preferences" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .edit {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDone) }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let user = store.me
            firstName = user.firstName
            lastName = user.lastName
            city = user.city
            season = user.season
            commitment = user.commitment
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.display(.headline)).foregroundStyle(.secondary)
            content()
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textContentType(.name)
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CommitmentCard: View {
    let commitment: Commitment
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: commitment.symbol)
                .font(.app(.title2, weight: .semibold))
            Text(commitment.label).font(.display(.headline))
            Text(commitment.detail)
                .font(.app(.caption))
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .foregroundStyle(isSelected ? .white : .primary)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Theme.primary.gradient) : AnyShapeStyle(Theme.card))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1)
        }
        .scaleEffect(isSelected ? 1.03 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
    }
}
