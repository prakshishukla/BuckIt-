import Foundation

/// Client for the BuckIt AI API (`backend/`), the small server that holds the Gemini key and talks to Gemini.
/// The app never calls Gemini directly and never contains the key. Used for photo verification,
/// list-item ideas and sponsor campaign ideas.
struct AIClient {
    let baseURL: URL
    let token: String

    /// nil when no API URL is configured (the app then uses offline demo fallbacks).
    static var configured: AIClient? {
        guard let url = URL(string: AppConfig.apiURL), url.scheme != nil else { return nil }
        return AIClient(baseURL: url, token: AppConfig.apiToken)
    }

    enum AIError: LocalizedError {
        case http(Int, String), unreachable

        var errorDescription: String? {
            switch self {
            case .unreachable: "Can't reach the BuckIt AI server. Is it running? (see backend/README.md)"
            case .http(_, let detail): detail
            }
        }
    }

    /// Who produced a reply. Shown in the UI and matches the server's audit log entry.
    struct Meta: Decodable {
        var requestId: String
        var model: String
        var promptVersion: String
        var latencyMs: Int
    }

    private struct ErrorBody: Decodable { var detail: String }

    /// Fire-and-forget GET /health at launch, so a free-tier host that sleeps when idle is awake by the time
    /// the first real request (often onboarding's Side Kick) arrives.
    static func warmUp() {
        guard let client = configured else { return }
        var request = URLRequest(url: client.baseURL.appending(path: "health"))
        request.timeoutInterval = 60
        Task.detached { _ = try? await URLSession.shared.data(for: request) }
    }

    /// POSTs `body` as JSON to `path` and decodes the reply. Keys are snake_case on the wire.
    func post<Body: Encodable, Reply: Decodable>(_ path: String, _ body: Body, as reply: Reply.Type,
                                                 timeout: TimeInterval = 70) async throws -> Reply {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { request.setValue(token, forHTTPHeaderField: "X-BuckIt-Token") }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .timedOut,
                                             .networkConnectionLost, .notConnectedToInternet].contains(error.code) {
            throw AIError.unreachable
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail ?? "Server returned HTTP \(http.statusCode)."
            throw AIError.http(http.statusCode, detail)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Reply.self, from: data)
    }
}

// MARK: - List item ideas (genAI for customers)

/// A suggested bucket-list item.
struct ItemIdea: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var description: String
    var location: String?
    var category: ChallengeCategory
    var commitment: Commitment
}

enum IdeaGenerator {
    private struct Request: Encodable {
        var listName: String
        var existingTitles: [String]
        var city: String
        var season: String
        var mood: String
    }

    private struct Reply: Decodable {
        struct Idea: Decodable {
            var title: String
            var description: String
            var location: String?
            var category: ChallengeCategory
            var commitment: Commitment
        }
        var ideas: [Idea]
    }

    /// Ideas for a list from the BuckIt AI API (Gemini). Uses curated offline ideas when no server is configured
    /// or it can't be reached; `fromGemini` says which.
    static func generate(listName: String, existingTitles: [String], city: String, season: Season,
                         mood: String) async throws -> (ideas: [ItemIdea], fromGemini: Bool) {
        guard let client = AIClient.configured else {
            try await Task.sleep(for: .seconds(1.0))
            return (offlineIdeas(excluding: existingTitles, mood: mood), false)
        }
        let request = Request(listName: listName, existingTitles: Array(existingTitles.prefix(40)), city: city,
                              season: season.rawValue, mood: mood)
        do {
            let reply = try await client.post("ideas", request, as: Reply.self)
            return (reply.ideas.map { ItemIdea(title: $0.title, description: $0.description, location: $0.location,
                                              category: $0.category, commitment: $0.commitment) }, true)
        } catch AIClient.AIError.unreachable {
            return (offlineIdeas(excluding: existingTitles, mood: mood), false)
        }
    }

    private static let offline: [ItemIdea] = [
        ItemIdea(title: "Sunrise at Kerry Park", description: "Catch first light over the skyline and Mt. Rainier.",
                 location: "Kerry Park, Queen Anne", category: .outdoors, commitment: .low),
        ItemIdea(title: "Ferry to Vashon for brunch", description: "Hop the Fauntleroy ferry and bike to a café.",
                 location: "Vashon Island", category: .smallTrips, commitment: .medium),
        ItemIdea(title: "Hike Lake Serene", description: "Waterfalls and a turquoise alpine lake at the top.",
                 location: "Index, WA", category: .outdoors, commitment: .high),
        ItemIdea(title: "Chinatown-ID food crawl", description: "Dumplings, bubble tea and bakeries in one afternoon.",
                 location: "Chinatown-International District", category: .food, commitment: .low),
        ItemIdea(title: "Fremont Solstice Parade", description: "Costumes, floats and a very Seattle summer party.",
                 location: "Fremont", category: .localEvents, commitment: .medium),
        ItemIdea(title: "Museum of Pop Culture night", description: "Explore the exhibits, then grab dinner nearby.",
                 location: "MoPOP, Seattle Center", category: .culture, commitment: .low),
        ItemIdea(title: "Karaoke at Rock Box", description: "Book a private room and belt it out.",
                 location: "Capitol Hill", category: .entertainment, commitment: .low),
        ItemIdea(title: "Bonfire at Golden Gardens", description: "Bring s'mores and claim a fire ring before sunset.",
                 location: "Golden Gardens, Ballard", category: .withFriends, commitment: .low),
        ItemIdea(title: "Camp at Olympic National Park", description: "Rainforest, beaches and mountains in one weekend.",
                 location: "Olympic Peninsula", category: .bigTrips, commitment: .high),
        ItemIdea(title: "Leavenworth day trip", description: "Bavarian village, river tubing and pretzels.",
                 location: "Leavenworth, WA", category: .smallTrips, commitment: .high),
        ItemIdea(title: "Bike the Alki Trail", description: "Ride the waterfront from the bridge to the lighthouse.",
                 location: "West Seattle", category: .outdoors, commitment: .medium),
        ItemIdea(title: "Dinner cruise on Lake Union", description: "Sunset, skyline and something tasty on deck.",
                 location: "Lake Union", category: .withFriends, commitment: .medium),
    ]

    private static func offlineIdeas(excluding titles: [String], mood: String) -> [ItemIdea] {
        let taken = Set(titles.map { $0.lowercased() })
        let words = mood.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 }
        let pool = offline.filter { !taken.contains($0.title.lowercased()) }
        let matching = pool.filter { idea in
            words.contains { w in
                (idea.title + " " + idea.description + " " + idea.category.label).lowercased().contains(w)
            }
        }
        return Array((matching + pool.shuffled()).reduce(into: [ItemIdea]()) { out, i in
            if !out.contains(where: { $0.title == i.title }) { out.append(i) }
        }.prefix(6))
    }
}
