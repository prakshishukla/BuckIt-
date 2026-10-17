import SwiftUI

struct ProfileView: View {
    enum Route: Hashable { case wallet, lists }

    @Environment(AppStore.self) private var store
    @State private var editingPreferences = false
    @State private var creatingList = false
    @State private var confirmReset = false
    @State private var editingColors = false

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.profilePath) {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    bucketCard
                    walletSection
                    listsSection
                    settingsSection
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .wallet: WalletView()
                case .lists: ListsView()
                }
            }
            .navigationDestination(for: ListRoute.self) { route in
                ListDetailView(listID: route.id, mode: .profile)
            }
            .navigationDestination(for: FriendRoute.self) { route in
                FriendProfileView(friendID: route.id)
            }
            .navigationDestination(for: Challenge.self) { challenge in
                ChallengeDetailView(challenge: challenge)
            }
            .sheet(isPresented: $editingPreferences) {
                NavigationStack {
                    PreferencesView(mode: .edit) { editingPreferences = false }
                }
            }
            .sheet(isPresented: $creatingList) { CreateListView() }
            .sheet(isPresented: $editingColors) { BucketColorsSheet() }
            .confirmationDialog("Reset the demo?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset demo", role: .destructive) { store.resetDemo() }
            } message: {
                Text("Clears posts, coupons and lists and returns to the sign-in screen.")
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
            Text(me.fullName).font(.display(.title, weight: .heavy))
            Button {
                editingPreferences = true
            } label: {
                HStack(spacing: 6) {
                    ChipView(text: me.city, symbol: "mappin", compact: true)
                    ChipView(text: me.season.label, symbol: me.season.symbol, tint: Theme.plum, compact: true)
                    ChipView(text: me.commitment.label, symbol: me.commitment.symbol, tint: Theme.teal, compact: true)
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
                Text("Your bucket").font(.display(.headline))
                Spacer()
                if store.bucketNumber > 1 {
                    Label("Bucket #\(store.bucketNumber)", systemImage: "trophy.fill")
                        .font(.app(.caption, weight: .bold))
                        .foregroundStyle(Theme.plumFixed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.cream, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }

            ZStack(alignment: .top) {
                WaterBucketView(level: store.bucketLevel, size: 180, layers: store.bucketLayers)
                SplashView(trigger: store.splashCount)
                    .padding(.top, 36)
            }
            .padding(.vertical, 6)

            Text("\(store.bucketDrops)/\(SeedData.dropsPerBucket) drops this season")
                .font(.display(.title3))
                .contentTransition(.numericText())
                .animation(.snappy, value: store.bucketDrops)
            if !store.bucketCategories.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(store.bucketCategories) { category in
                        HStack(spacing: 5) {
                            Circle().fill(store.waterColor(category)).frame(width: 10, height: 10)
                            Text(category.label).font(.app(.caption, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.background, in: Capsule())
                    }
                }
            }
            Text("Each completed item adds a layer in its activity's color. Fill it up to start Bucket #\(store.bucketNumber + 1).")
                .font(.app(.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                editingColors = true
            } label: {
                Label("Bucket colors", systemImage: "paintpalette.fill")
                    .font(.app(.subheadline, weight: .semibold))
            }
            .padding(.top, 2)
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
                    Label("Wallet", systemImage: "wallet.pass.fill").font(.display(.title3))
                    Spacer()
                    Text("\(store.me.wallet.filter { !$0.redeemed }.count) active")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.app(.subheadline, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if let latest = store.me.wallet.first {
                CouponCardView(coupon: latest)
            } else {
                Text("Complete a sponsored challenge to unlock real discounts. 🎁")
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        }
    }

    // MARK: - Lists

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: Route.lists) {
                HStack {
                    Label("My Lists", systemImage: "list.bullet").font(.display(.title3))
                    Spacer()
                    Image(systemName: "chevron.right").font(.app(.subheadline, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            ForEach(store.activeLists) { list in
                NavigationLink(value: ListRoute(id: list.id)) { ListRow(list: list) }
                    .buttonStyle(.plain)
            }

            Button {
                creatingList = true
            } label: {
                Label("Create list", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle())

            if !store.completedLists.isEmpty {
                Label("Completed lists", systemImage: "checkmark.seal.fill")
                    .font(.display(.title3))
                    .foregroundStyle(Theme.teal)
                    .padding(.top, 10)
                ForEach(store.completedLists) { list in
                    NavigationLink(value: ListRoute(id: list.id)) { ListRow(list: list) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.display(.title3))
            VStack(spacing: 0) {
                Toggle(isOn: Binding(get: { store.state.seedFeedEnabled },
                                     set: { on in withAnimation { store.setSeedFeed(on) } })) {
                    Label("Seed demo feed", systemImage: "sparkles.rectangle.stack")
                }
                .padding(.vertical, 10)
                Divider()
                HStack {
                    Label("Photo check", systemImage: "sparkles")
                    Spacer()
                    Text(store.verifier.displayName)
                        .font(.app(.caption))
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
