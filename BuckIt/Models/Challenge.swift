import Foundation

struct Sponsor: Codable, Hashable {
    var name: String
    var colorHex: String
    var symbol: String
    /// Asset slot for an official logo. Drop an image with this name into Assets.xcassets
    /// (only with the brand's permission) and SponsorBadge will use it instead of the SF Symbol.
    var logoAsset: String? = nil
}

struct RewardTemplate: Codable, Hashable {
    var headline: String
    var detail: String
    var codePrefix: String
    var expiresInDays: Int
}

struct Challenge: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var category: ChallengeCategory
    var location: String?
    var commitment: Commitment
    /// nil = not sponsored
    var sponsor: Sponsor? = nil
    /// Submission criteria (sponsored only).
    var criteria: [String] = []
    var reward: RewardTemplate? = nil
    /// Sub-heading inside a group's list, e.g. "Local" or "Parks & Adventures".
    var section: String? = nil
    /// Optional SF Symbol override for the card icon.
    var symbol: String? = nil

    var isSponsored: Bool { sponsor != nil }
    var iconSymbol: String { symbol ?? sponsor?.symbol ?? category.symbol }
}
