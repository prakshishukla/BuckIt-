import CoreLocation
import UIKit

struct CriterionResult: Identifiable, Hashable {
    let id = UUID()
    var criterion: String
    var met: Bool
    var why: String
}

struct VerificationResult {
    var verified: Bool
    var criteria: [CriterionResult]
    var confidence: Double
    /// "Gemini", or "Demo" for the offline mock / fallback.
    var source: String
}

protocol VerificationService {
    var displayName: String { get }
    func verify(photo: UIImage, challenge: Challenge, location: CLLocation?, date: Date) async throws -> VerificationResult
}

/// Values injected from Config/*.xcconfig through Info.plist.
enum AppConfig {
    private static func value(_ key: String) -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespaces)
        return raw.hasPrefix("$(") ? "" : raw // unexpanded build setting = unset
    }

    static var geminiAPIKey: String {
        let key = value("GEMINI_API_KEY")
        return key == "your-key-here" ? "" : key
    }

    static var geminiModel: String {
        let model = value("GEMINI_MODEL")
        return model.isEmpty ? "gemini-flash-latest" : model
    }

    static var forceVerify: Bool {
        !["NO", "FALSE", "0"].contains(value("FORCE_VERIFY").uppercased())
    }
}

enum VerificationServiceFactory {
    static func make() -> any VerificationService {
        let key = AppConfig.geminiAPIKey
        if key.isEmpty { return MockVerificationService() }
        return GeminiVerificationService(apiKey: key, model: AppConfig.geminiModel, forceVerify: AppConfig.forceVerify)
    }
}

// MARK: - Mock (default)

/// Offline verifier used when no Gemini key is configured: always succeeds.
struct MockVerificationService: VerificationService {
    var displayName: String { "Demo mode (offline)" }

    func verify(photo: UIImage, challenge: Challenge, location: CLLocation?, date: Date) async throws -> VerificationResult {
        try await Task.sleep(for: .seconds(0.9))
        return Self.passing(challenge, note: "Looks good!", source: "Demo")
    }

    static func passing(_ challenge: Challenge, note: String, source: String) -> VerificationResult {
        VerificationResult(verified: true,
                           criteria: challenge.criteria.map { CriterionResult(criterion: $0, met: true, why: note) },
                           confidence: 0.97, source: source)
    }
}

// MARK: - Gemini

/// Sends the photo + challenge criteria to Gemini and asks for a strict JSON verdict,
/// then adds on-device checks for timestamp recency and location.
struct GeminiVerificationService: VerificationService {
    let apiKey: String
    let model: String
    /// When true, submissions always verify (keeps the stage demo safe). Per-criterion results are still shown as Gemini returned them.
    let forceVerify: Bool

    var displayName: String { "Gemini · \(model)" + (forceVerify ? " · force-verify" : "") }

    enum GeminiError: LocalizedError {
        case badImage, http(Int, String), emptyResponse, badJSON(String)
        var errorDescription: String? {
            switch self {
            case .badImage: "Couldn't encode the photo."
            case .http(let code, let body): "Gemini returned HTTP \(code). \(body.prefix(160))"
            case .emptyResponse: "Gemini returned no answer."
            case .badJSON(let text): "Gemini's answer wasn't valid JSON: \(text.prefix(120))"
            }
        }
    }

    func verify(photo: UIImage, challenge: Challenge, location: CLLocation?, date: Date) async throws -> VerificationResult {
        do {
            let verdict = try await askGemini(photo: photo, challenge: challenge)
            var criteria = verdict.criteria.map { CriterionResult(criterion: $0.criterion, met: $0.met, why: $0.why) }

            let recent = abs(date.timeIntervalSinceNow) < 48 * 3600
            criteria.append(CriterionResult(criterion: "Taken recently", met: recent,
                                            why: recent ? "Captured \(date.formatted(.relative(presentation: .named)))" : "Photo is more than 2 days old"))

            var nearby = true
            if let location {
                let km = location.distance(from: LocationService.seattle) / 1000
                nearby = km < 150
                criteria.append(CriterionResult(criterion: "Near the challenge", met: nearby,
                                                why: String(format: "%.0f km from Seattle", km)))
            }

            let passed = verdict.matches && recent && nearby
            return VerificationResult(verified: forceVerify || passed, criteria: criteria,
                                      confidence: verdict.confidence, source: "Gemini")
        } catch {
            guard forceVerify, !(error is CancellationError) else { throw error }
            print("BuckIt: Gemini verification failed, using demo fallback: \(error)")
            return MockVerificationService.passing(challenge, note: "Gemini unreachable: demo fallback", source: "Demo")
        }
    }

    private struct Verdict: Decodable {
        struct Item: Decodable { var criterion: String; var met: Bool; var why: String }
        var matches: Bool
        var criteria: [Item]
        var confidence: Double
    }

    private struct GenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { var text: String? }
                var parts: [Part]?
            }
            var content: Content?
        }
        var candidates: [Candidate]?
    }

    private func askGemini(photo: UIImage, challenge: Challenge) async throws -> Verdict {
        guard let jpeg = photo.resized(maxDimension: 1024).jpegData(compressionQuality: 0.7) else { throw GeminiError.badImage }

        let criteriaList = challenge.criteria.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        You are the proof checker for BuckIt, an app where friends complete real-world challenges and upload a photo as proof.

        Challenge: \(challenge.title)
        Description: \(challenge.description)
        Submission criteria:
        \(criteriaList)

        Judge ONLY from what is visible in the photo. For criteria about location or timestamp metadata, mark met = true \
        (the app checks those separately). Be fair but not gullible.

        Respond with strict JSON only, no markdown:
        {"matches": bool, "criteria": [{"criterion": string, "met": bool, "why": string}], "confidence": number between 0 and 1}
        Use each criterion's text exactly as given, in the same order. Keep each "why" under 12 words.
        """

        let imagePart: [String: Any] = [
            "inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()] as [String: String],
        ]
        let textPart: [String: Any] = ["text": prompt]
        let content: [String: Any] = ["role": "user", "parts": [textPart, imagePart] as [[String: Any]]]
        let generationConfig: [String: Any] = ["temperature": 0, "response_mime_type": "application/json"]
        let body: [String: Any] = [
            "contents": [content] as [[String: Any]],
            "generationConfig": generationConfig,
        ]

        let modelPath = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelPath):generateContent")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw GeminiError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(), !text.isEmpty else {
            throw GeminiError.emptyResponse
        }
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try JSONDecoder().decode(Verdict.self, from: Data(cleaned.utf8))
        } catch {
            throw GeminiError.badJSON(cleaned)
        }
    }
}
