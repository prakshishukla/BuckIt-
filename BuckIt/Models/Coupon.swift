import Foundation

struct Coupon: Codable, Identifiable, Hashable {
    var id: UUID
    var challengeID: String
    var sponsorName: String
    var sponsorColorHex: String
    var sponsorSymbol: String
    var headline: String
    var detail: String
    var code: String
    var expiresAt: Date
    var redeemed: Bool
    /// What they bought with it, shared after marking it used.
    var purchaseNote: String? = nil

    var sponsor: Sponsor { Sponsor(name: sponsorName, colorHex: sponsorColorHex, symbol: sponsorSymbol) }
}
