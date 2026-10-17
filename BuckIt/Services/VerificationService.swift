import CoreLocation
import ImageIO
import UIKit

struct CriterionResult: Identifiable, Hashable {
    let id = UUID()
    var criterion: String
    var met: Bool
    var why: String
    /// Check couldn't run (e.g. the photo has no GPS). Shown as a dash, doesn't block.
    var skipped = false
}

struct VerificationResult {
    var verified: Bool
    var criteria: [CriterionResult]
    var confidence: Double
    /// "Gemini", or "Demo" for the offline mock.
    var source: String
}

/// Where and when the photo was taken, and where that info came from.
struct PhotoEvidence {
    var location: CLLocation?
    var date: Date
    /// "photo GPS" (EXIF) or "phone location"
    var locationSource: String
    /// "photo timestamp" (EXIF) or "capture time"
    var dateSource: String
}

/// GPS + original timestamp read from a photo's EXIF data (library photos often have these).
struct PhotoMetadata {
    var location: CLLocation?
    var date: Date?

    static func read(from data: Data) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return PhotoMetadata() }
        var meta = PhotoMetadata()
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           var lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           var lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            if (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S" { lat = -lat }
            if (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W" { lon = -lon }
            meta.location = CLLocation(latitude: lat, longitude: lon)
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            meta.date = f.date(from: original)
        }
        return meta
    }
}

extension Challenge {
    /// What Gemini checks in the photo. Sponsored items use the sponsor's criteria; everything else gets
    /// criteria from its title and description.
    var verificationCriteria: [String] {
        if !criteria.isEmpty { return criteria.filter { !$0.lowercased().contains("location + timestamp") } }
        return ["Photo shows: \(title)", "Looks like a real photo taken there, not a screenshot"]
    }

    /// How far from Seattle still counts (big trips go further).
    var allowedKilometers: Double { category == .bigTrips ? 400 : 150 }
}

protocol VerificationService {
    var displayName: String { get }
    var usesGemini: Bool { get }
    func verify(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> VerificationResult
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

    /// YES = always pass (stage safety net). Default NO: Gemini's verdict decides.
    static var forceVerify: Bool {
        ["YES", "TRUE", "1"].contains(value("FORCE_VERIFY").uppercased())
    }
}

enum VerificationServiceFactory {
    static func make() -> any VerificationService {
        let key = AppConfig.geminiAPIKey
        if key.isEmpty { return MockVerificationService() }
        return GeminiVerificationService(apiKey: key, model: AppConfig.geminiModel, forceVerify: AppConfig.forceVerify)
    }
}

/// On-device checks combined with Gemini's verdict: is the photo recent, and was it taken near the item?
enum EvidenceChecks {
    static func run(_ evidence: PhotoEvidence, challenge: Challenge) -> [CriterionResult] {
        var results: [CriterionResult] = []

        let age = Date().timeIntervalSince(evidence.date)
        let recent = age < 7 * 86400
        results.append(CriterionResult(criterion: "Taken recently", met: recent,
                                       why: "\(evidence.dateSource.capitalized): \(evidence.date.formatted(.relative(presentation: .named)))"))

        if let location = evidence.location {
            let km = location.distance(from: LocationService.seattle) / 1000
            let near = km <= challenge.allowedKilometers
            results.append(CriterionResult(criterion: "Taken near \(challenge.location ?? "Seattle")", met: near,
                                           why: "\(evidence.locationSource.capitalized): \(Int(km.rounded())) km from Seattle"))
        } else {
            results.append(CriterionResult(criterion: "Taken near \(challenge.location ?? "Seattle")", met: true,
                                           why: "No location data, so this check was skipped", skipped: true))
        }
        return results
    }
}

// MARK: - Mock (no API key)

/// Offline verifier used when no Gemini key is configured. The photo checks always pass; the
/// on-device time/location checks still run for real.
struct MockVerificationService: VerificationService {
    var displayName: String { "Offline demo (add a Gemini key to enable)" }
    var usesGemini: Bool { false }

    func verify(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> VerificationResult {
        try await Task.sleep(for: .seconds(0.9))
        let photoChecks = challenge.verificationCriteria.map { CriterionResult(criterion: $0, met: true, why: "Offline demo: not checked by Gemini") }
        return VerificationResult(verified: true, criteria: photoChecks + EvidenceChecks.run(evidence, challenge: challenge),
                                  confidence: 1, source: "Demo")
    }
}

// MARK: - Gemini

/// Sends the photo + the item's criteria to Gemini's vision model and asks for a strict JSON verdict,
/// then combines it with on-device checks of the photo's timestamp and location.
struct GeminiVerificationService: VerificationService {
    let apiKey: String
    let model: String
    let forceVerify: Bool

    var displayName: String { "Gemini · \(model)" + (forceVerify ? " · force-verify" : "") }
    var usesGemini: Bool { true }

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

    func verify(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> VerificationResult {
        do {
            let verdict = try await askGemini(photo: photo, challenge: challenge, evidence: evidence)
            let photoChecks = verdict.criteria.map { CriterionResult(criterion: $0.criterion, met: $0.met, why: $0.why) }
            let evidenceChecks = EvidenceChecks.run(evidence, challenge: challenge)
            let passed = verdict.matches && photoChecks.allSatisfy(\.met) && evidenceChecks.allSatisfy(\.met)
            return VerificationResult(verified: forceVerify || passed, criteria: photoChecks + evidenceChecks,
                                      confidence: verdict.confidence, source: "Gemini")
        } catch {
            guard forceVerify, !(error is CancellationError) else { throw error }
            print("BuckIt: Gemini verification failed, force-verify fallback: \(error)")
            let checks = challenge.verificationCriteria.map { CriterionResult(criterion: $0, met: true, why: "Gemini unreachable: force-verify fallback") }
            return VerificationResult(verified: true, criteria: checks + EvidenceChecks.run(evidence, challenge: challenge),
                                      confidence: 0, source: "Demo")
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

    private func askGemini(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> Verdict {
        guard let jpeg = photo.resized(maxDimension: 1024).jpegData(compressionQuality: 0.7) else { throw GeminiError.badImage }

        let criteriaList = challenge.verificationCriteria.map { "- \($0)" }.joined(separator: "\n")
        let metadata = [
            "Taken: \(evidence.date.formatted(date: .abbreviated, time: .shortened)) (\(evidence.dateSource))",
            evidence.location.map { String(format: "Location: %.4f, %.4f (%@)", $0.coordinate.latitude, $0.coordinate.longitude, evidence.locationSource) }
                ?? "Location: unknown",
        ].joined(separator: "\n")

        let prompt = """
        You are the proof checker for BuckIt, a Seattle app where friends complete bucket-list items and post a photo as proof.

        Item: \(challenge.title)
        Description: \(challenge.description)
        Where: \(challenge.location ?? "anywhere")
        Photo metadata (for context only):
        \(metadata)

        Criteria to judge from the photo:
        \(criteriaList)

        Judge ONLY from what is visible in the photo. Be fair (casual phone photos are fine) but not gullible: \
        a photo that clearly shows something unrelated to the item does not match.

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
