import CoreLocation
import Observation

/// One-shot current location + reverse-geocoded place name for tagging challenge photos.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let seattle = CLLocation(latitude: 47.6062, longitude: -122.3321)

    var location: CLLocation?
    var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break // denied: the UI keeps the fallback place name
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        location = latest
        geocoder.reverseGeocodeLocation(latest) { [weak self] placemarks, _ in
            guard let place = placemarks?.first else { return }
            let primary = place.areasOfInterest?.first ?? place.name ?? place.subLocality
            let parts = [primary, place.locality].compactMap { $0 }
            let name = parts.count == 2 && parts[0] == parts[1] ? parts[0] : parts.joined(separator: ", ")
            DispatchQueue.main.async {
                if !name.isEmpty { self?.placeName = name }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No fix (e.g. Simulator without a GPX location): the UI keeps the fallback place name.
    }
}
