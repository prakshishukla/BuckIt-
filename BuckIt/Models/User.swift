import Foundation

struct User: Codable, Identifiable {
    var id: UUID
    var firstName: String
    var lastName: String
    var city: String
    var season: Season
    var commitment: Commitment
    var listIDs: [UUID]
    var wallet: [Coupon]
    /// Drives the water bucket on Profile.
    var completedCount: Int
    /// Used by the (fake) contacts list.
    var isOnBuckIt: Bool
    var phone: String?

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String { "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased() }
}
