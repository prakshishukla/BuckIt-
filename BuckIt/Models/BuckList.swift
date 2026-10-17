import Foundation

/// A shared bucket list. People are simply members of the list.
struct BuckList: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var emoji: String
    var memberIDs: [UUID]
    var challengeIDs: [String]
}
