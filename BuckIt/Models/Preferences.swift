import Foundation

/// low < 2 hrs, medium = half day, high = full day+
enum Commitment: String, Codable, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var detail: String {
        switch self {
        case .low: "Under 2 hrs"
        case .medium: "Half day"
        case .high: "Full day+"
        }
    }

    var symbol: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "arrow.right"
        case .high: "arrow.up"
        }
    }
}

enum Season: String, Codable, CaseIterable, Identifiable {
    case spring, summer, fall, winter

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .spring: "camera.macro"
        case .summer: "sun.max.fill"
        case .fall: "leaf.fill"
        case .winter: "snowflake"
        }
    }
}

/// Activity type. The same set is used for sponsored challenges, list items, filters and bucket water colors.
/// Named `ChallengeCategory` (not `Category`) to avoid clashing with the Objective-C runtime's `Category` type.
enum ChallengeCategory: String, Codable, CaseIterable, Identifiable {
    case outdoors, bigTrips, smallTrips, food, localEvents, culture, entertainment, withFriends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .outdoors: "Outdoors"
        case .bigTrips: "Big trips"
        case .smallTrips: "Small trips"
        case .food: "Food"
        case .localEvents: "Local events"
        case .culture: "Culture"
        case .entertainment: "Entertainment"
        case .withFriends: "With friends"
        }
    }

    var symbol: String {
        switch self {
        case .outdoors: "tree.fill"
        case .bigTrips: "airplane"
        case .smallTrips: "car.fill"
        case .food: "fork.knife"
        case .localEvents: "mappin.and.ellipse"
        case .culture: "building.columns.fill"
        case .entertainment: "music.note"
        case .withFriends: "person.3.fill"
        }
    }

    /// Default water color for this type in the bucket (changeable in Profile → Bucket colors).
    var defaultHex: String {
        switch self {
        case .outdoors: "#3F8F7B"
        case .bigTrips: "#05668D"
        case .smallTrips: "#2BA3B5"
        case .food: "#E07A5F"
        case .localEvents: "#E9B44C"
        case .culture: "#513B56"
        case .entertainment: "#8E7CC3"
        case .withFriends: "#D96C9A"
        }
    }
}
