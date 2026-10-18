import Foundation

/// Minimal Gemini client using the Interactions API (`POST /v1beta/interactions`), which is what new API keys use.
/// Returns the model's JSON answer decoded as `T`. Used for photo verification, list-item ideas and sponsor campaign ideas.
struct GeminiClient {
    let apiKey: String
    let model: String

    /// nil when no key is configured (the app then uses offline demo fallbacks).
    static var configured: GeminiClient? {
        let key = AppConfig.geminiAPIKey
        return key.isEmpty ? nil : GeminiClient(apiKey: key, model: AppConfig.geminiModel)
    }

    enum GeminiError: LocalizedError {
        case http(Int, String), emptyResponse, badJSON(String)
        var errorDescription: String? {
            switch self {
            case .http(429, _): "Gemini's free-tier limit was hit. Wait a minute and try again."
            case .http(503, _): "Gemini is busy right now. Try again in a moment."
            case .http(let code, let body): "Gemini returned HTTP \(code). \(body.prefix(160))"
            case .emptyResponse: "Gemini returned no answer."
            case .badJSON(let text): "Gemini's answer wasn't valid JSON: \(text.prefix(120))"
            }
        }
    }

    private struct InteractionResponse: Decodable {
        struct Step: Decodable {
            struct Content: Decodable { var text: String? }
            var type: String?
            var content: [Content]?
        }
        var steps: [Step]?
    }

    /// Models to try in order: the configured one first, then fallbacks for when it's overloaded
    /// (free-tier keys often see 503 "high demand" on the newest models).
    private var modelChain: [String] {
        var chain = [model]
        for fallback in ["gemini-3-flash-preview", "gemini-3.1-flash-lite", "gemini-3.5-flash"] where !chain.contains(fallback) {
            chain.append(fallback)
        }
        return chain
    }

    /// Sends a prompt (and optionally a JPEG) and decodes the JSON reply as `T`, falling back across models.
    func generate<T: Decodable>(_ type: T.Type, prompt: String, jpeg: Data? = nil) async throws -> T {
        var lastError: Error = GeminiError.emptyResponse
        for candidate in modelChain {
            do {
                return try await generate(type, model: candidate, prompt: prompt, jpeg: jpeg)
            } catch let error as GeminiError {
                lastError = error
                if case .http(let code, _) = error, [404, 429, 500, 503].contains(code) { continue } // busy / unavailable
                throw error
            } catch let error as URLError where error.code == .timedOut {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private func generate<T: Decodable>(_ type: T.Type, model: String, prompt: String, jpeg: Data?) async throws -> T {
        var input: [[String: Any]] = [["type": "text", "text": prompt]]
        if let jpeg {
            input.append(["type": "image", "data": jpeg.base64EncodedString(), "mime_type": "image/jpeg"])
        }
        let body: [String: Any] = ["model": model, "input": input]

        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw GeminiError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(InteractionResponse.self, from: data)
        let text = (decoded.steps ?? [])
            .filter { $0.type == "model_output" }
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined()
        guard !text.isEmpty else { throw GeminiError.emptyResponse }
        return try Self.decodeJSON(T.self, from: text)
    }

    /// Strips markdown fences / surrounding prose and decodes the first JSON object in the text.
    static func decodeJSON<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}"), start < end {
            cleaned = String(cleaned[start...end])
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(cleaned.utf8))
        } catch {
            throw GeminiError.badJSON(cleaned)
        }
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
    /// Set when the idea is an existing catalog item (e.g. Alki Beach), so it opens with its photo and details.
    var challengeID: String? = nil
}

enum IdeaGenerator {
    private struct Reply: Decodable {
        struct Idea: Decodable {
            var title: String
            var description: String
            var location: String?
            var category: String
            var commitment: String
        }
        var ideas: [Idea]
    }

    /// Ideas for a list. Uses Gemini when a key is set; otherwise returns curated offline ideas.
    static func generate(listName: String, existingTitles: [String], city: String, season: Season,
                         mood: String) async throws -> (ideas: [ItemIdea], fromGemini: Bool) {
        if let beach = beachIdeas(for: mood) {
            try await Task.sleep(for: .seconds(1.2))
            return (beach, false)
        }
        guard let client = GeminiClient.configured else {
            try await Task.sleep(for: .seconds(1.0))
            return (offlineIdeas(excluding: existingTitles, mood: mood), false)
        }
        let types = ChallengeCategory.allCases.map(\.rawValue).joined(separator: ", ")
        let prompt = """
        Suggest 6 fresh bucket-list items for a group of friends in \(city) this \(season.label.lowercased()).
        The list is called "\(listName)". \(mood.isEmpty ? "" : "They're in the mood for: \(mood).")
        Don't repeat anything already on it: \(existingTitles.prefix(40).joined(separator: "; ")).
        Make them specific, real places or events, fun, and doable. Mix effort levels.

        Respond with strict JSON only:
        {"ideas": [{"title": string (max 6 words), "description": string (one sentence), "location": string,
                    "category": one of [\(types)], "commitment": one of [low, medium, high]}]}
        """
        let reply = try await client.generate(Reply.self, prompt: prompt)
        let ideas = reply.ideas.map { idea in
            ItemIdea(title: idea.title, description: idea.description, location: idea.location,
                     category: ChallengeCategory(rawValue: idea.category)
                        ?? ChallengeCategory.allCases.first { $0.label.lowercased() == idea.category.lowercased() } ?? .outdoors,
                     commitment: Commitment(rawValue: idea.commitment.lowercased()) ?? .medium)
        }
        return (ideas, true)
    }

    /// Hardcoded demo: "Hangout by the beach" always leads with our Alki Beach item, then other beach ideas.
    private static func beachIdeas(for mood: String) -> [ItemIdea]? {
        let normalized = mood.lowercased().filter { $0.isLetter || $0 == " " }
            .split(separator: " ").joined(separator: " ")
        guard ["hangout by the beach", "hang out by the beach"].contains(normalized),
              let alki = SeedData.challenge(SeedData.alkiID) else { return nil }
        return [
            ItemIdea(title: alki.title, description: alki.description, location: alki.location,
                     category: alki.category, commitment: alki.commitment, challengeID: alki.id),
            ItemIdea(title: "Bonfire at Golden Gardens", description: "Grab a fire ring before sunset and bring s'mores for the crew.",
                     location: "Golden Gardens Park, Ballard", category: .withFriends, commitment: .low),
            ItemIdea(title: "Tide pools at Discovery Park", description: "Walk down to West Point at low tide and spot sea stars.",
                     location: "Discovery Park, Magnolia", category: .outdoors, commitment: .medium),
            ItemIdea(title: "Swim at Madison Park Beach", description: "Float off the dock on Lake Washington, then grab ice cream nearby.",
                     location: "Madison Park", category: .outdoors, commitment: .low),
            ItemIdea(title: "Sunset picnic at Carkeek Park", description: "Pack a blanket and watch the trains roll by the beach.",
                     location: "Carkeek Park, North Seattle", category: .food, commitment: .low),
            ItemIdea(title: "Beach day at Richmond Beach", description: "Quiet sand, Olympic Mountain views and room for frisbee.",
                     location: "Richmond Beach Saltwater Park, Shoreline", category: .withFriends, commitment: .medium),
        ]
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
