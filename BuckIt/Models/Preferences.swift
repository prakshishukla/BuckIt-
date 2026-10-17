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

/// Named `ChallengeCategory` (not `Category`) to avoid clashing with the Objective-C runtime's `Category` type.
enum ChallengeCategory: String, Codable, CaseIterable, Identifiable {
    case hike, water, park, island, market, ride, shopping, finance

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .hike: "figure.hiking"
        case .water: "figure.pool.swim"
        case .park: "tree.fill"
        case .island: "ferry.fill"
        case .market: "basket.fill"
        case .ride: "bicycle"
        case .shopping: "cart.fill"
        case .finance: "creditcard.fill"
        }
    }
}
