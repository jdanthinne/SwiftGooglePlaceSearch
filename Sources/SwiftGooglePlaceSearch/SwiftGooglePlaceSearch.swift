import AsyncCompatibilityKit
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

    public enum GooglePlaceSearchError: Error {
        case invalidResponse
        case serverError(statusCode: Int)
    }

    public init(googleAPIKey: String) {
        self.googleAPIKey = googleAPIKey
    }

    // MARK: - Autocompletion

    struct AutocompleteResponse: Decodable {
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
                             language: ResultsLanguage = .current) async throws -> [AutocompletePrediction]
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

        let results = try await data(ofType: AutocompleteResponse.self, request: request(endpoint: "autocomplete", args: args))

        return results.predictions
    }

    // MARK: - Place Details

    struct PlaceDetailsResponse: Decodable {
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
                                  language: ResultsLanguage = .current) async throws -> PlaceDetailsResult
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

        let response = try await data(ofType: PlaceDetailsResponse.self, request: request(endpoint: "details", args: args))

        return response.result
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

    private func data<T: Decodable>(ofType type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw GooglePlaceSearchError.invalidResponse
        }

        guard response.statusCode == 200 else {
            throw GooglePlaceSearchError.serverError(statusCode: response.statusCode)
        }

        return try jsonDecoder.decode(type.self, from: data)
    }
}

public extension SwiftGooglePlaceSearch.PlaceDetailsResult {
    func addressComponent(ofType type: String) -> SwiftGooglePlaceSearch.PlaceDetailsComponent? {
        addressComponents.first(where: { $0.types.contains(type) })
    }
}
