import SwiftUI

struct CouponCardView: View {
    @Environment(AppStore.self) private var store
    let coupon: Coupon
    var showsActions = true
    @State private var copied = false
    @State private var sharingPurchase = false

    var body: some View {
        let brand = Color(hex: coupon.sponsorColorHex)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SponsorBadge(sponsor: coupon.sponsor, style: .onColor, compact: true)
                Spacer()
                Text("DEMO")
                    .font(.app(.caption2, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.25), in: Capsule())
                    .accessibilityLabel("Demo reward")
            }

            Text(coupon.headline)
                .font(.display(.title2, weight: .heavy))
            Text(coupon.detail)
                .font(.app(.subheadline))
                .opacity(0.88)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CODE").font(.app(.caption2, weight: .bold)).opacity(0.75)
                    Button {
                        UIPasteboard.general.string = coupon.code
                        withAnimation { copied = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(coupon.code).font(.system(.title3, design: .monospaced, weight: .bold))
                            Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.app(.caption))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Code \(coupon.code). Tap to copy.")
                    Text("Expires \(coupon.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.app(.caption))
                        .opacity(0.8)
                }
                Spacer()
                QRCodeView(text: coupon.code)
                    .frame(width: 86, height: 86)
                    .padding(6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let note = coupon.purchaseNote {
                Label("Bought: \(note)", systemImage: "bag.fill")
                    .font(.app(.subheadline, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
            }

            if showsActions {
                Button {
                    if coupon.redeemed {
                        withAnimation(.snappy) { store.setRedeemed(coupon.id, false) }
                    } else {
                        sharingPurchase = true
                    }
                } label: {
                    Label(coupon.redeemed ? "Used · tap to undo" : "Mark as used",
                          systemImage: coupon.redeemed ? "arrow.uturn.backward" : "checkmark.circle")
                        .font(.app(.subheadline, weight: .semibold))
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
                    .font(.display(size: 44, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.9), lineWidth: 4))
                    .rotationEffect(.degrees(-14))
            }
        }
        .saturation(coupon.redeemed ? 0.1 : 1)
        .shadow(color: brand.opacity(0.3), radius: 14, y: 8)
        .sheet(isPresented: $sharingPurchase) {
            SharePurchaseSheet(coupon: coupon)
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

/// After using a coupon: say what you bought, and optionally share it on your post (sponsors see it too).
struct SharePurchaseSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let coupon: Coupon
    @State private var note = ""
    @State private var shareToFeed = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Better Sweater fleece 🧥", text: $note)
                } header: {
                    Text("What did you get with \(coupon.headline.lowercased())?")
                }
                Section {
                    Toggle("Share it on my post", isOn: $shareToFeed)
                } footer: {
                    Text("Your friends see it on your \(coupon.sponsorName) post, and \(coupon.sponsorName) sees it in their Sponsor View.")
                }
            }
            .navigationTitle("Mark as used")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        withAnimation(.snappy) { store.recordPurchase(coupon.id, note: note, shareToFeed: shareToFeed) }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
