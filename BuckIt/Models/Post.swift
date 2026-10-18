import Foundation

struct Comment: Codable, Identifiable {
    var id: UUID
    var userID: UUID
    var text: String
    var date: Date
}

struct Post: Codable, Identifiable {
    var id: UUID
    var userID: UUID
    var listID: UUID
    var challengeID: String
    /// JPEG filename in Documents/photos, or "asset:<name>" for bundled images.
    var photoFilename: String
    var selfieFilename: String?
    var locationName: String
    var date: Date
    var taggedUserIDs: [UUID]
    /// emoji -> user IDs
    var reactions: [String: [UUID]]
    var comments: [Comment]
    var caption: String?
    /// Set when the author taps "Share to feed" on the coupon reveal.
    var sharedRewardHeadline: String?
    /// "Got a Better Sweater 🧥" — shared from the wallet after using the coupon.
    var sharedPurchase: String? = nil
}
