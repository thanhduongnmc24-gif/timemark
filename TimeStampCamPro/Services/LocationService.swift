import Foundation
import CoreLocation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentAddress: String = ""
    @Published var currentCoordinates: String = ""
    @Published var isFetching: Bool = false
    @Published var headingSymbol: String = "D"

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var completionHandler: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation(completion: ((String) -> Void)? = nil) {
        self.completionHandler = completion
        self.isFetching = true

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        } else {
            self.isFetching = false
            let fallback = "Khu liên hợp Gang Thép Hòa Phát Dung Quất, Quảng Ngãi"
            self.currentAddress = fallback
            completion?(fallback)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        } else if status == .denied || status == .restricted {
            DispatchQueue.main.async {
                self.isFetching = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let deg = newHeading.magneticHeading
        guard deg >= 0 else { return }
        let symbol: String
        switch deg {
        case 337.5...360.0, 0..<22.5: symbol = "B"
        case 22.5..<67.5: symbol = "ĐB"
        case 67.5..<112.5: symbol = "Đ"
        case 112.5..<157.5: symbol = "ĐN"
        case 157.5..<202.5: symbol = "N"
        case 202.5..<247.5: symbol = "TN"
        case 247.5..<292.5: symbol = "T"
        default: symbol = "TB"
        }
        DispatchQueue.main.async {
            self.headingSymbol = symbol
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            DispatchQueue.main.async { self.isFetching = false }
            return
        }

        let lat = String(format: "%.5f°N", location.coordinate.latitude)
        let lon = String(format: "%.5f°E", location.coordinate.longitude)
        let coordText = "\(lat), \(lon)"

        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "vi_VN")) { [weak self] placemarks, _ in
            guard let self = self else { return }
            var parts: [String] = []
            if let place = placemarks?.first {
                if let name = place.name, !name.isEmpty { parts.append(name) }
                if let subAdmin = place.subAdministrativeArea, !subAdmin.isEmpty, !parts.contains(subAdmin) {
                    parts.append(subAdmin)
                }
                if let admin = place.administrativeArea, !admin.isEmpty, !parts.contains(admin) {
                    parts.append(admin)
                }
            }
            let resolved = parts.isEmpty ? coordText : parts.joined(separator: ", ")
            DispatchQueue.main.async {
                self.currentCoordinates = coordText
                self.currentAddress = resolved
                self.isFetching = false
                self.completionHandler?(resolved)
                self.completionHandler = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isFetching = false
            if self.currentAddress.isEmpty {
                self.currentAddress = "Bình Đông, Bình Sơn, Quảng Ngãi"
            }
            self.completionHandler?(self.currentAddress)
            self.completionHandler = nil
        }
    }
}
