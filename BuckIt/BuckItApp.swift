import SwiftUI

@main
struct BuckItApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.water)
        }
    }
}

/// Sign in → onboarding → tabs.
struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            if !store.state.hasSignedIn {
                SignInView()
                    .transition(.opacity)
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
                .tabItem { Label("Challenges", systemImage: "target") }
                .tag(AppTab.challenges)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "drop.fill") }
                .tag(AppTab.profile)
        }
        .fullScreenCover(item: $store.activeCapture) { challenge in
            CaptureFlowView(challenge: challenge)
        }
    }
}
