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

/// Values injected from Config/*.xcconfig through Info.plist. None of these are secret: the Gemini key
/// lives only on the BuckIt AI server (backend/.env).
enum AppConfig {
    private static func value(_ key: String) -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespaces)
        return raw.hasPrefix("$(") ? "" : raw // unexpanded build setting = unset
    }

    /// Base URL of the BuckIt AI API, e.g. http://127.0.0.1:8000. Empty = offline demo mode.
    static var apiURL: String { value("BUCKIT_API_URL") }

    /// Optional shared token the server checks (BUCKIT_APP_TOKEN on the server).
    static var apiToken: String { value("BUCKIT_API_TOKEN") }

    /// YES = always pass (stage safety net). Default NO: Gemini's verdict decides.
    static var forceVerify: Bool {
        ["YES", "TRUE", "1"].contains(value("FORCE_VERIFY").uppercased())
    }
}

enum VerificationServiceFactory {
    static func make() -> any VerificationService {
        guard let client = AIClient.configured else { return MockVerificationService() }
        return BackendVerificationService(client: client, forceVerify: AppConfig.forceVerify)
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
    var displayName: String { "Offline demo (set BUCKIT_API_URL to enable)" }
    var usesGemini: Bool { false }

    func verify(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> VerificationResult {
        try await Task.sleep(for: .seconds(0.9))
        let photoChecks = challenge.verificationCriteria.map { CriterionResult(criterion: $0, met: true, why: "Offline demo: not checked by Gemini") }
        return VerificationResult(verified: true, criteria: photoChecks + EvidenceChecks.run(evidence, challenge: challenge),
                                  confidence: 1, source: "Demo")
    }
}

// MARK: - Gemini (through the BuckIt AI API)

/// Sends the photo + the item's criteria to the BuckIt AI API, which asks Gemini vision for a strict JSON verdict
/// and applies the confidence threshold. The verdict is combined with on-device checks of the photo's
/// timestamp and location. GPS coordinates never leave the phone.
struct BackendVerificationService: VerificationService {
    let client: AIClient
    let forceVerify: Bool

    var displayName: String {
        "Gemini via \(client.baseURL.host() ?? "BuckIt API")" + (forceVerify ? " · force-verify" : "")
    }
    var usesGemini: Bool { true }

    private struct Request: Encodable {
        struct Item: Encodable { var title: String; var description: String; var location: String?; var criteria: [String] }
        var item: Item
        var photoJpegBase64: String
        var takenAt: Date
        var dateSource: String
    }

    private struct Verdict: Decodable {
        struct Item: Decodable { var criterion: String; var met: Bool; var why: String }
        var criteria: [Item]
        var confidence: Double
        /// Server-side: matches AND every criterion met AND confidence >= threshold.
        var verified: Bool
        var meta: AIClient.Meta
    }

    func verify(photo: UIImage, challenge: Challenge, evidence: PhotoEvidence) async throws -> VerificationResult {
        do {
            guard let jpeg = photo.resized(maxDimension: 1024).jpegData(compressionQuality: 0.7) else { throw CocoaError(.fileWriteUnknown) }
            let request = Request(item: .init(title: challenge.title, description: challenge.description,
                                              location: challenge.location, criteria: challenge.verificationCriteria),
                                  photoJpegBase64: jpeg.base64EncodedString(), takenAt: evidence.date, dateSource: evidence.dateSource)
            let verdict = try await client.post("verify", request, as: Verdict.self)
            let photoChecks = verdict.criteria.map { CriterionResult(criterion: $0.criterion, met: $0.met, why: $0.why) }
            let evidenceChecks = EvidenceChecks.run(evidence, challenge: challenge)
            let passed = verdict.verified && evidenceChecks.allSatisfy(\.met)
            return VerificationResult(verified: forceVerify || passed, criteria: photoChecks + evidenceChecks,
                                      confidence: verdict.confidence, source: "Gemini")
        } catch {
            guard forceVerify, !(error is CancellationError) else { throw error }
            print("BuckIt: verification failed, force-verify fallback: \(error)")
            let checks = challenge.verificationCriteria.map { CriterionResult(criterion: $0, met: true, why: "AI server unreachable: force-verify fallback") }
            return VerificationResult(verified: true, criteria: checks + EvidenceChecks.run(evidence, challenge: challenge),
                                      confidence: 0, source: "Demo")
        }
    }
}
