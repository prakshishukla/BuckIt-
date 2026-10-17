import SwiftUI

struct WalletView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let active = store.me.wallet.filter { !$0.redeemed }
        let used = store.me.wallet.filter(\.redeemed)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.me.wallet.isEmpty {
                    EmptyStateView(symbol: "wallet.pass", title: "No rewards yet",
                                   message: "Complete a sponsored challenge to unlock real discounts.",
                                   actionTitle: "See sponsored challenges") {
                        store.selectedTab = .challenges
                    }
                    .padding(.top, 40)
                }
                ForEach(active) { CouponCardView(coupon: $0) }
                if !used.isEmpty {
                    Text("Used").font(.rounded(.headline)).foregroundStyle(.secondary).padding(.top, 8)
                    ForEach(used) { CouponCardView(coupon: $0) }
                }
            }
            .padding(16)
            .animation(.snappy, value: store.me.wallet.map(\.redeemed))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Wallet")
    }
}
