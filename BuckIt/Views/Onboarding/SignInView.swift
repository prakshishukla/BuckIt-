import SwiftUI

struct SignInView: View {
    @Environment(AppStore.self) private var store
    @State private var showCodeAlert = false
    @State private var code = ""
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#6BB4F7"), Color(hex: "#2F80ED"), Theme.navyFixed],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                WaterBucketView(level: appeared ? 0.62 : 0.05, size: 150, outline: Theme.navyFixed)
                    .environment(\.colorScheme, .light)
                    .animation(.spring(duration: 1.6, bounce: 0.3).delay(0.25), value: appeared)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .animation(.spring(duration: 0.8, bounce: 0.4), value: appeared)

                VStack(spacing: 10) {
                    Text("BuckIt")
                        .font(.system(size: 58, weight: .heavy, design: .rounded))
                    Text("Kick the bucket list. Together.")
                        .font(.rounded(.title3, weight: .semibold))
                        .opacity(0.92)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        store.signIn()
                    } label: {
                        Label("Continue as Buck It", systemImage: "person.crop.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(background: .white, foreground: Theme.navyFixed))

                    Button("Join with invite code") { showCodeAlert = true }
                        .font(.rounded(.headline))
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                }

                Text("Demo build · no real account needed")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
        }
        .onAppear { appeared = true }
        .alert("Join a group", isPresented: $showCodeAlert) {
            TextField("Invite code", text: $code)
                .textInputAutocapitalization(.characters)
            Button("Join") { store.joinWithInvite(code) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the code a friend sent you to join \(SeedData.crewGroupName).")
        }
    }
}
