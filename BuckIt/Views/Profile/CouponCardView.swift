import SwiftUI

struct CouponCardView: View {
    @Environment(AppStore.self) private var store
    let coupon: Coupon
    var showsActions = true
    @State private var copied = false

    var body: some View {
        let brand = Color(hex: coupon.sponsorColorHex)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SponsorBadge(sponsor: coupon.sponsor, style: .onColor, compact: true)
                Spacer()
                Text("DEMO")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.25), in: Capsule())
                    .accessibilityLabel("Demo reward")
            }

            Text(coupon.headline)
                .font(.rounded(.title2, weight: .heavy))
            Text(coupon.detail)
                .font(.subheadline)
                .opacity(0.88)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CODE").font(.caption2.weight(.bold)).opacity(0.75)
                    Button {
                        UIPasteboard.general.string = coupon.code
                        withAnimation { copied = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(coupon.code).font(.system(.title3, design: .monospaced, weight: .bold))
                            Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Code \(coupon.code). Tap to copy.")
                    Text("Expires \(coupon.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                QRCodeView(text: coupon.code)
                    .frame(width: 86, height: 86)
                    .padding(6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if showsActions {
                Button {
                    withAnimation(.snappy) { store.setRedeemed(coupon.id, !coupon.redeemed) }
                } label: {
                    Label(coupon.redeemed ? "Used · tap to undo" : "Mark as used",
                          systemImage: coupon.redeemed ? "arrow.uturn.backward" : "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [brand, brand.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            if coupon.redeemed {
                Text("USED")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.9), lineWidth: 4))
                    .rotationEffect(.degrees(-14))
            }
        }
        .saturation(coupon.redeemed ? 0.1 : 1)
        .shadow(color: brand.opacity(0.3), radius: 14, y: 8)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
