import Combine
import CoreLocation
import Foundation

public final class SwiftGooglePlaceSearch {
    let googleAPIKey: String

    private lazy var googleSessionToken = UUID().uuidString
    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    public enum ResultsLanguage {
        case current
        case languageCode(String)

        var languageCode: String? {
            switch self {
            case .current: return Locale.current.languageCode
            case let .languageCode(language): return language
            }
        }
    }

    public init(googleAPIKey: String) {
        self.googleAPIKey = googleAPIKey
    }

    // MARK: - Autocompletion

    public struct AutocompleteResponse: Decodable {
        public let predictions: [AutocompletePrediction]
    }

    public struct AutocompletePrediction: Decodable {
        public let distanceMeters: Double?
        public let placeId: String
        public let structuredFormatting: AutocompleteText
    }

    public struct AutocompleteText: Decodable {
        public let mainText: String
        public let secondaryText: String
    }

    public enum AutocompleteType: String {
        case geocode, address, establishment
        case cities = "(cities)"
        case regions = "(regions)"
    }

    public enum AutocompleteCountry {
        case current
        case countryCode(String)

        var countryCode: String? {
            switch self {
            case .current: return Locale.current.regionCode
            case let .countryCode(code): return code
            }
        }
    }

    public func autocomplete(input: String,
                             type: AutocompleteType? = nil,
                             origin: CLLocationCoordinate2D? = nil,
                             location: CLLocationCoordinate2D? = nil,
                             radiusInMeters: Int? = nil,
                             countries: [AutocompleteCountry] = [],
                             language: ResultsLanguage = .current) -> AnyPublisher<AutocompleteResponse, Error>
    {
        var args: [String: String] = [
            "input": input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "",
            "key": googleAPIKey,
            "sessiontoken": googleSessionToken,
        ]

        if let type = type {
            args["type"] = type.rawValue
        }

        if let origin = origin {
            args["origin"] = "\(origin.latitude),\(origin.longitude)"
        }

        if let location = location {
            args["location"] = "\(location.latitude),\(location.longitude)"
        }

        if let radiusInMeters = radiusInMeters {
            args["radius"] = radiusInMeters.description
        }

        let countryCodes = countries.compactMap(\.countryCode)
        if !countryCodes.isEmpty {
            args["components"] = "country:\(countryCodes.joined(separator: "|"))"
        }

        if let languageCode = language.languageCode {
            args["language"] = languageCode
        }

        return URLSession.shared
            .dataTaskPublisher(for: request(endpoint: "autocomplete", args: args))
            .retry(1)
            .map(\.data)
            .decode(type: AutocompleteResponse.self, decoder: jsonDecoder)
            .eraseToAnyPublisher()
    }

    // MARK: - Place Details

    public struct PlaceDetailsResponse: Decodable {
        public let result: PlaceDetailsResult
    }

    public struct PlaceDetailsResult: Decodable {
        public let addressComponents: [PlaceDetailsComponent]
        public let geometry: PlaceDetailsGeometry
    }

    public struct PlaceDetailsComponent: Decodable {
        public let longName: String
        public let shortName: String
        public let types: [String]
    }

    public struct PlaceDetailsGeometry: Decodable {
        public let location: PlaceDetailsLocation
    }

    public struct PlaceDetailsLocation: Decodable {
        public let lat: Double
        public let lng: Double
    }

    public enum PlaceDetailsFields: String {
        case addressComponent = "address_component"
        case geometry
    }

    public func fetchPlaceDetails(placeID: String,
                                  fields: [PlaceDetailsFields] = [],
                                  language: ResultsLanguage = .current) -> AnyPublisher<PlaceDetailsResponse, Error>
    {
        var args: [String: String] = [
            "place_id": placeID,
            "key": googleAPIKey,
            "sessiontoken": googleSessionToken,
        ]

        if !fields.isEmpty {
            args["fields"] = fields.map(\.rawValue).joined(separator: ",")
        }

        if let languageCode = language.languageCode {
            args["language"] = languageCode
        }

        return URLSession.shared
            .dataTaskPublisher(for: request(endpoint: "details", args: args))
            .retry(1)
            .map(\.data)
            .decode(type: PlaceDetailsResponse.self, decoder: jsonDecoder)
            .eraseToAnyPublisher()
    }

    // MARK: - Helpers

    private func request(endpoint: String, args: [String: String]) -> URLRequest {
        let query = args
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")

        var request = URLRequest(url: URL(string: "https://maps.googleapis.com/maps/api/place/\(endpoint)/json?\(query)")!)
        request.httpMethod = "GET"

        return request
    }
}

public extension SwiftGooglePlaceSearch.PlaceDetailsResult {
    func addressComponent(ofType type: String) -> SwiftGooglePlaceSearch.PlaceDetailsComponent? {
        addressComponents.first(where: { $0.types.contains(type) })
    }
}
