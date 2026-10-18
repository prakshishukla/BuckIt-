import SwiftUI

@main
struct BuckItApp: App {
    @State private var store = AppStore()

    init() {
        AppearanceSetup.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.primary)
                .font(.app(.body))
        }
    }
}

/// Sign in → privacy agreement → onboarding → tabs.
struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            if !store.state.hasSignedIn {
                SignInView()
                    .transition(.opacity)
            } else if store.state.privacyAcceptedAt == nil {
                NavigationStack { PrivacyAgreementView() }
                    .transition(.move(edge: .trailing))
            } else if !store.state.hasOnboarded {
                OnboardingFlow()
                    .transition(.move(edge: .trailing))
            } else {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.smooth(duration: 0.45), value: store.state.hasSignedIn)
        .animation(.smooth(duration: 0.45), value: store.state.hasOnboarded)
        .animation(.smooth(duration: 0.45), value: store.state.privacyAcceptedAt)
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            FeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            ChallengesView()
                .tabItem { Label("Challenges", systemImage: "list.bullet") }
                .tag(AppTab.challenges)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTab.profile)
            SponsorView()
                .tabItem { Label("Sponsor View", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.sponsor)
        }
        .fullScreenCover(item: $store.activeCapture) { request in
            CaptureFlowView(request: request)
        }
        .overlay {
            if let colors = store.overflowColors {
                BucketOverflowView(colors: colors, bucketNumber: store.bucketNumber)
                    .transition(.opacity)
            }
        }
    }
}
