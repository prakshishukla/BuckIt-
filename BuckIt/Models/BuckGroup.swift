import Foundation

/// A friend group with a shared bucket list.
/// Named `BuckGroup` (not `Group`) so it doesn't shadow SwiftUI's `Group` view.
struct BuckGroup: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var emoji: String
    var memberIDs: [UUID]
    var challengeIDs: [String]
    /// Title of the group's bucket list, e.g. "Seattle Bucket List 2026".
    var listName: String
}
