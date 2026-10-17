import SwiftUI

struct ProfileView: View {
    enum Route: Hashable { case wallet, groups }

    @Environment(AppStore.self) private var store
    @State private var editingPreferences = false
    @State private var creatingGroup = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    bucketCard
                    walletSection
                    groupsSection
                    settingsSection
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .wallet: WalletView()
                case .groups: GroupsView()
                }
            }
            .sheet(isPresented: $editingPreferences) {
                NavigationStack {
                    PreferencesView(mode: .edit) { editingPreferences = false }
                }
            }
            .sheet(isPresented: $creatingGroup) { CreateGroupView() }
            .confirmationDialog("Reset the demo?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset demo", role: .destructive) { store.resetDemo() }
            } message: {
                Text("Clears posts, coupons and groups and returns to the sign-in screen.")
            }
        }
        .onAppear { Task { await store.animateBucketIfNeeded() } }
        .onChange(of: store.selectedTab) { _, tab in
            if tab == .profile { Task { await store.animateBucketIfNeeded() } }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: store.splashCount)
    }

    // MARK: - Header

    private var header: some View {
        let me = store.me
        return VStack(spacing: 12) {
            AvatarView(user: me, size: 84)
            Text(me.fullName).font(.rounded(.title, weight: .heavy))
            Button {
                editingPreferences = true
            } label: {
                HStack(spacing: 6) {
                    ChipView(text: me.city, symbol: "mappin", compact: true)
                    ChipView(text: me.season.label, symbol: me.season.symbol, tint: Color(hex: "#E08A1E"), compact: true)
                    ChipView(text: me.commitment.label, symbol: me.commitment.symbol, tint: Theme.evergreen, compact: true)
                    Image(systemName: "pencil.circle.fill").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit preferences: \(me.city), \(me.season.label), \(me.commitment.label) commitment")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Bucket

    private var bucketCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Your bucket").font(.rounded(.headline))
                Spacer()
                if store.bucketNumber > 1 {
                    Label("Bucket #\(store.bucketNumber)", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.navyFixed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.sunshine, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }

            ZStack(alignment: .top) {
                WaterBucketView(level: store.bucketLevel, size: 180)
                SplashView(trigger: store.splashCount)
                    .padding(.top, 36)
            }
            .padding(.vertical, 6)

            Text("\(store.bucketDrops)/\(SeedData.dropsPerBucket) drops this season")
                .font(.rounded(.title3))
                .contentTransition(.numericText())
                .animation(.snappy, value: store.bucketDrops)
            Text("Every completed challenge adds a drop. Fill it up to start Bucket #\(store.bucketNumber + 1).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
        .animation(.spring, value: store.bucketNumber)
    }

    // MARK: - Wallet

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: Route.wallet) {
                HStack {
                    Label("Wallet", systemImage: "wallet.pass.fill").font(.rounded(.title3))
                    Spacer()
                    Text("\(store.me.wallet.filter { !$0.redeemed }.count) active")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if let latest = store.me.wallet.first {
                CouponCardView(coupon: latest)
            } else {
                Text("Complete a sponsored challenge to unlock real discounts. 🎁")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        }
    }

    // MARK: - Groups

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: Route.groups) {
                HStack {
                    Label("My Groups", systemImage: "person.3.fill").font(.rounded(.title3))
                    Spacer()
                    Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            ForEach(store.myGroups) { GroupRow(group: $0) }

            Button {
                creatingGroup = true
            } label: {
                Label("Create group", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.rounded(.title3))
            VStack(spacing: 0) {
                Toggle(isOn: Binding(get: { store.state.seedFeedEnabled },
                                     set: { on in withAnimation { store.setSeedFeed(on) } })) {
                    Label("Seed demo feed", systemImage: "sparkles.rectangle.stack")
                }
                .padding(.vertical, 10)
                Divider()
                HStack {
                    Label("Verification", systemImage: "checkmark.seal")
                    Spacer()
                    Text(store.verifier.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 10)
                Divider()
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Label("Reset demo", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 10)
            }
            .card(padding: 14)
        }
    }
}
