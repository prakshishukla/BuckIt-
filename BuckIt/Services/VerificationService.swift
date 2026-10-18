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

    /// Place name for the "Taken near …" check; vague locations ("Any trail…", "Anywhere…") read as Seattle.
    var nearbyPlaceName: String {
        guard let location, !location.lowercased().hasPrefix("any") else { return "Seattle" }
        return location
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
        return model.isEmpty ? "gemini-3-flash-preview" : model
    }

    /// YES = show the "Need more ideas?" link to our Side Kick on UW Purple (Cloudforce × DubHacks).
    /// NO = no mention of UW Purple anywhere in the app.
    static var cloudforce: Bool {
        ["YES", "TRUE", "1"].contains(value("CLOUDFORCE").uppercased())
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
            results.append(CriterionResult(criterion: "Taken near \(challenge.nearbyPlaceName)", met: near,
                                           why: "\(evidence.locationSource.capitalized): \(Int(km.rounded())) km from Seattle"))
        } else {
            results.append(CriterionResult(criterion: "Taken near \(challenge.nearbyPlaceName)", met: true,
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


    private func askGemini(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> Verdict {
        guard let jpeg = photo.resized(maxDimension: 1024).jpegData(compressionQuality: 0.7) else { throw CocoaError(.fileWriteUnknown) }

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

        return try await GeminiClient(apiKey: apiKey, model: model).generate(Verdict.self, prompt: prompt, jpeg: jpeg)
    }
}
