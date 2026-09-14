import Foundation

/// The coordinate reference system carried by a transit data source.
///
/// Coordinates from the AMap Web Service are GCJ-02.  They must not be
/// silently passed to a model that promises WGS-84/MapKit coordinates.  The
/// app can add an explicitly approved conversion adapter later; this layer
/// deliberately does not contain an undocumented coordinate conversion.
enum MainlandCoordinateSystem: String, Codable, Hashable, Sendable {
    case wgs84
    case gcj02
}

/// A coordinate with its source reference system attached.
struct MainlandCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let system: MainlandCoordinateSystem

    init?(
        latitude: Double,
        longitude: Double,
        system: MainlandCoordinateSystem
    ) {
        guard latitude.isFinite,
              longitude.isFinite,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude)
        else { return nil }

        self.latitude = latitude
        self.longitude = longitude
        self.system = system
    }

    static func wgs84(latitude: Double, longitude: Double) -> MainlandCoordinate? {
        MainlandCoordinate(latitude: latitude, longitude: longitude, system: .wgs84)
    }

    static func gcj02(latitude: Double, longitude: Double) -> MainlandCoordinate? {
        MainlandCoordinate(latitude: latitude, longitude: longitude, system: .gcj02)
    }
}

extension StopLocation {
    init(_ coordinate: MainlandCoordinate) {
        self.init(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            coordinateSystem: coordinate.system == .gcj02 ? .gcj02 : .wgs84
        )
    }
}

/// Mainland city identifiers used in official service requests.
///
/// `adcode` and `citycode` are preferred over a display name.  AMap accepts
/// either code in its `city` parameter, so the provider keeps both values when
/// the catalog has them and chooses `adcode` first for deterministic requests.
struct MainlandCityIdentifier: Codable, Hashable, Sendable {
    let name: String?
    let adcode: String?
    let citycode: String?

    init(name: String? = nil, adcode: String? = nil, citycode: String? = nil) {
        self.name = Self.clean(name)
        self.adcode = Self.clean(adcode)
        self.citycode = Self.clean(citycode)
    }

    var preferredCode: String? {
        adcode ?? citycode ?? name
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum MainlandTransitMode: String, Codable, Hashable, Sendable {
    case bus
    case metro
    case unknown
}

/// Identifies which part of a composed provider produced a value.
enum MainlandDataSource: String, Codable, Hashable, Sendable {
    case amapBase
    case chelaileAPI
    case authorizedRealtime
    case legacyFallback
    case composite
}

enum MainlandCapability: String, Codable, Hashable, Sendable {
    case search
    case nearby
    case stopBoard
    case linePayload
    case realtime
}

/// Errors that a provider may surface to a router or to SwiftUI.
enum MainlandProviderError: Error, LocalizedError, Hashable, Sendable {
    case unsupported(MainlandCapability)
    case realtimeUnavailable(source: String)
    case providerUnavailable(providerID: String, reason: String)
    case missingConfiguration(String)
    case invalidRequest(String)
    case noData

    /// A router may try its explicitly supplied fallback for these cases.
    var isFallbackEligible: Bool {
        switch self {
        case .unsupported, .realtimeUnavailable, .providerUnavailable, .missingConfiguration:
            return true
        case .invalidRequest:
            return false
        case .noData:
            return true
        }
    }

    var errorDescription: String? {
        switch self {
        case let .unsupported(capability):
            return "The mainland provider does not support \(capability.rawValue)."
        case let .realtimeUnavailable(source):
            return "Real-time arrival data is unavailable from \(source)."
        case let .providerUnavailable(providerID, reason):
            return "Provider \(providerID) is unavailable: \(reason)"
        case let .missingConfiguration(message):
            return message
        case let .invalidRequest(message):
            return message
        case .noData:
            return "The provider returned no transit data."
        }
    }
}

struct MainlandLineSummary: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let lineID: String
    let name: String
    let origin: String
    let destination: String
    let operatorName: String?
    let mode: MainlandTransitMode
    let serviceStatus: String?
    let firstDeparture: String?
    let lastDeparture: String?
    let fare: String?
    let city: MainlandCityIdentifier?
    let source: MainlandDataSource
}

struct MainlandStopSummary: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let stopID: String
    let namesakeStopID: String?
    let name: String
    let subtitle: String?
    let location: MainlandCoordinate?
    let city: MainlandCityIdentifier?
    let source: MainlandDataSource
}

struct MainlandSearchResults: Codable, Hashable, Sendable {
    var lines: [MainlandLineSummary]
    var stops: [MainlandStopSummary]

    init(lines: [MainlandLineSummary] = [], stops: [MainlandStopSummary] = []) {
        self.lines = lines
        self.stops = stops
    }

    static let empty = MainlandSearchResults()
}

struct MainlandNearbyArrival: Codable, Hashable, Sendable {
    let lineID: String?
    let lineName: String
    let destination: String
    let minutes: Int?
    let source: MainlandDataSource
}

struct MainlandNearbyStop: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let stopID: String
    let namesakeStopID: String?
    let name: String
    let distanceMeters: Double?
    let location: MainlandCoordinate?
    let arrivals: [MainlandNearbyArrival]
    let source: MainlandDataSource
}

struct MainlandBoardLine: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let lineID: String
    let lineName: String
    let destination: String
    let targetStopSequence: Int?
    let status: String?
    let minutes: [Int]
    let source: MainlandDataSource
}

struct MainlandTransitLine: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let lineID: String
    let name: String
    let mode: MainlandTransitMode
    let color: String?

    init(
        id: String,
        lineID: String? = nil,
        name: String,
        mode: MainlandTransitMode,
        color: String? = nil
    ) {
        self.id = id
        self.lineID = lineID ?? id
        self.name = name
        self.mode = mode
        self.color = color
    }
}

struct MainlandStopBoardResult: Codable, Hashable, Sendable {
    var rows: [MainlandBoardLine]
    var otherLines: [MainlandTransitLine]
    var location: StopLocation?

    init(
        rows: [MainlandBoardLine] = [],
        otherLines: [MainlandTransitLine] = [],
        location: StopLocation? = nil
    ) {
        self.rows = rows
        self.otherLines = otherLines
        self.location = location
    }
}

/// Base route data returned by a line-detail provider.
///
/// This is intentionally independent of `RouteEntry`/`StopEntry`: those
/// legacy database models use untagged coordinates, while AMap returns
/// GCJ-02.  A caller that needs the shared route UI must perform an explicit
/// adapter step and decide how the coordinate boundary is handled.
struct MainlandLinePayload: Codable, Hashable, Sendable {
    let line: MainlandLineSummary
    let stops: [MainlandStopSummary]
    let polyline: [MainlandCoordinate]
    let coordinateSystem: MainlandCoordinateSystem
    let source: MainlandDataSource

    var stopIDs: [String] {
        stops.map(\.stopID)
    }

    var routeMetadata: MainlandRouteMetadata {
        MainlandRouteMetadata(
            mode: line.mode,
            firstDeparture: line.firstDeparture,
            lastDeparture: line.lastDeparture,
            fare: line.fare,
            source: source
        )
    }
}

/// Metadata that is not represented by the shared legacy `RouteEntry` model.
/// Query-mode routes keep this beside their synthetic entry so the standard
/// route screens can still show service hours and mode-specific behavior.
struct MainlandRouteMetadata: Codable, Hashable, Sendable {
    let mode: MainlandTransitMode
    let firstDeparture: String?
    let lastDeparture: String?
    let fare: String?
    let source: MainlandDataSource
}

/// A small identity model useful when adapting a payload into an existing
/// static route database entry without leaking a data-source type into UI.
struct MainlandRouteIdentity: Codable, Hashable, Sendable {
    let lineID: String
    let lineName: String
    let origin: String
    let destination: String
}

extension MainlandLinePayload {
    func applying(modeHint: MainlandTransitMode?) -> MainlandLinePayload {
        guard let modeHint, modeHint != line.mode else { return self }
        let updatedLine = MainlandLineSummary(
            id: line.id,
            lineID: line.lineID,
            name: line.name,
            origin: line.origin,
            destination: line.destination,
            operatorName: line.operatorName,
            mode: modeHint,
            serviceStatus: line.serviceStatus,
            firstDeparture: line.firstDeparture,
            lastDeparture: line.lastDeparture,
            fare: line.fare,
            city: line.city,
            source: line.source
        )
        return MainlandLinePayload(
            line: updatedLine,
            stops: stops,
            polyline: polyline,
            coordinateSystem: coordinateSystem,
            source: source
        )
    }

    var routeIdentity: MainlandRouteIdentity {
        MainlandRouteIdentity(
            lineID: line.lineID,
            lineName: line.name,
            origin: line.origin,
            destination: line.destination
        )
    }
}

/// Query-mode capability used by mainland screens.  It deliberately does
/// not inherit the static Hong Kong database protocol; a shared UI adapter
/// can consume `MainlandLinePayload` and then register its own neutral route
/// and stop models.
protocol MainlandTransitProvider: Sendable {
    var id: String { get }
    var regionName: String { get }
    var city: MainlandCityIdentifier { get }
    var timeZone: TimeZone { get }
    var dataSource: MainlandDataSource { get }
    var supportsRealtimeETAs: Bool { get }

    func search(keyword: String) async throws -> MainlandSearchResults
    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop]
    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult
    func linePayload(
        lineID: String,
        modeHint: MainlandTransitMode?
    ) async throws -> MainlandLinePayload?

    /// A base-data provider may implement this by forwarding to an injected
    /// real-time provider, or by throwing `realtimeUnavailable`.
    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        latitude: Double?,
        longitude: Double?,
        source: MainlandDataSource?,
        language: AppLanguage,
        modeHint: MainlandTransitMode?
    ) async throws -> [Eta]
}

extension MainlandTransitProvider {
    func linePayload(lineID: String) async throws -> MainlandLinePayload? {
        try await linePayload(lineID: lineID, modeHint: nil)
    }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        source: MainlandDataSource? = nil,
        language: AppLanguage
    ) async throws -> [Eta] {
        try await fetchEtas(
            lineID: lineID,
            stopID: stopID,
            stopSequence: stopSequence,
            latitude: latitude,
            longitude: longitude,
            source: source,
            language: language,
            modeHint: nil
        )
    }

    func nearby(latitude: Double, longitude: Double) async throws -> [MainlandNearbyStop] {
        try await nearby(latitude: latitude, longitude: longitude, limit: 20)
    }
}

/// Mainland uses the shared filter picker, but only bus and metro have a
/// meaningful mainland mapping. Stops belong to the bus search result; metro
/// search deliberately suppresses ordinary bus stop hits.
enum MainlandSearchFiltering {
    static func apply(
        _ filter: TransportFilter,
        to results: MainlandSearchResults
    ) -> MainlandSearchResults {
        switch filter {
        case .all:
            return results
        case .bus:
            return MainlandSearchResults(
                lines: results.lines.filter { $0.mode != .metro },
                stops: results.stops
            )
        case .mtr:
            return MainlandSearchResults(
                lines: results.lines.filter { $0.mode == .metro },
                stops: []
            )
        case .minibus, .lightRail, .ferry:
            return .empty
        }
    }

    static func isSupported(_ filter: TransportFilter) -> Bool {
        filter == .all || filter == .bus || filter == .mtr
    }
}

enum MainlandRealtimePolicy {
    static func allowsRequest(modeHint: MainlandTransitMode?) -> Bool {
        modeHint != .metro
    }
}

/// Optional capability for a separately authorized real-time data source.
/// AMap intentionally does not conform to this protocol: its official bus
/// Web Service exposes base route/stop data, not live vehicle arrivals.
protocol MainlandRealtimeProvider: Sendable {
    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        latitude: Double?,
        longitude: Double?,
        source: MainlandDataSource?,
        language: AppLanguage,
        modeHint: MainlandTransitMode?
    ) async throws -> [Eta]
}

/// Composes official base data, an optional explicitly supplied fallback, and
/// an optional separately authorized real-time provider.
struct MainlandProviderRouter: MainlandTransitProvider {
    let primary: any MainlandTransitProvider
    let fallback: (any MainlandTransitProvider)?
    let realtime: (any MainlandRealtimeProvider)?

    init(
        primary: any MainlandTransitProvider,
        fallback: (any MainlandTransitProvider)? = nil,
        realtime: (any MainlandRealtimeProvider)? = nil
    ) {
        self.primary = primary
        self.fallback = fallback
        self.realtime = realtime
    }

    var id: String { primary.id }
    var regionName: String { primary.regionName }
    var city: MainlandCityIdentifier { primary.city }
    var timeZone: TimeZone { primary.timeZone }
    var dataSource: MainlandDataSource { .composite }
    var supportsRealtimeETAs: Bool { realtime != nil || primary.supportsRealtimeETAs }

    func search(keyword: String) async throws -> MainlandSearchResults {
        do {
            return try await primary.search(keyword: keyword)
        } catch {
            return try await fallbackOrRethrow(error) { try await $0.search(keyword: keyword) }
        }
    }

    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop] {
        do {
            return try await primary.nearby(latitude: latitude, longitude: longitude, limit: limit)
        } catch {
            return try await fallbackOrRethrow(error) {
                try await $0.nearby(latitude: latitude, longitude: longitude, limit: limit)
            }
        }
    }

    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult {
        do {
            return try await primary.stopBoard(stopID: stopID, namesakeStopID: namesakeStopID)
        } catch {
            return try await fallbackOrRethrow(error) {
                try await $0.stopBoard(stopID: stopID, namesakeStopID: namesakeStopID)
            }
        }
    }

    func linePayload(
        lineID: String,
        modeHint: MainlandTransitMode?
    ) async throws -> MainlandLinePayload? {
        do {
            if let payload = try await primary.linePayload(lineID: lineID, modeHint: modeHint) {
                return payload
            }
            if let fallback {
                return try await fallback.linePayload(lineID: lineID, modeHint: modeHint)
            }
            return nil
        } catch {
            return try await fallbackOrRethrow(error) {
                try await $0.linePayload(lineID: lineID, modeHint: modeHint)
            }
        }
    }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        source: MainlandDataSource? = nil,
        language: AppLanguage,
        modeHint: MainlandTransitMode?
    ) async throws -> [Eta] {
        // AMap IDs are not CheLaile API physical/sId identities. Do not
        // issue a plausible-looking but invalid realtime request for a route
        // that came from the official AMap base provider.
        if source == .amapBase {
            throw MainlandProviderError.realtimeUnavailable(
                source: "AMap base route has no compatible CheLaile station identity"
            )
        }
        if let realtime {
            do {
                return try await realtime.fetchEtas(
                    lineID: lineID,
                    stopID: stopID,
                    stopSequence: stopSequence,
                    latitude: latitude,
                    longitude: longitude,
                    source: source,
                    language: language,
                    modeHint: modeHint
                )
            } catch {
                if fallback == nil || !Self.isFallbackEligible(error) {
                    throw error
                }
            }
        }

        if let fallback {
            return try await fallback.fetchEtas(
                lineID: lineID,
                stopID: stopID,
                stopSequence: stopSequence,
                latitude: latitude,
                longitude: longitude,
                source: source,
                language: language,
                modeHint: modeHint
            )
        }

        if primary.supportsRealtimeETAs {
            return try await primary.fetchEtas(
                lineID: lineID,
                stopID: stopID,
                stopSequence: stopSequence,
                latitude: latitude,
                longitude: longitude,
                source: source,
                language: language,
                modeHint: modeHint
            )
        }

        throw MainlandProviderError.realtimeUnavailable(source: primary.id)
    }

    private func fallbackOrRethrow<T>(
        _ error: Error,
        operation: (any MainlandTransitProvider) async throws -> T
    ) async throws -> T {
        guard let fallback, Self.isFallbackEligible(error) else { throw error }
        return try await operation(fallback)
    }

    private static func isFallbackEligible(_ error: Error) -> Bool {
        guard !Task.isCancelled else { return false }
        if let mainlandError = error as? MainlandProviderError {
            return mainlandError.isFallbackEligible
        }
        if let amapError = error as? AMapError {
            switch amapError {
            case .invalidParameter:
                return false
            case .missingAPIKey, .invalidURL, .invalidResponse, .httpStatus,
                 .apiError, .transport, .decoding:
                return true
            }
        }
        if let apiError = error as? CheLaileAPIError {
            return apiError.isFallbackEligible
        }
        return false
    }
}

/// Factory used by the app integration layer.  It keeps the legacy provider
/// opaque: callers supply it as `fallback`, and no data-source-specific type
/// is referenced from this foundation layer.
enum MainlandProviderFactory {
    /// Makes the hosted CheLaile API the complete primary provider. If AMap
    /// is configured it is used only as a base-data fallback, with legacy
    /// direct CheLaile behind it. This prevents AMap IDs from being sent to
    /// the hosted realtime endpoint.
    static func apiPrimaryOrAmapFallback(
        primary: any MainlandTransitProvider,
        city: MainlandCityIdentifier,
        regionName: String,
        fallback: any MainlandTransitProvider,
        realtime: (any MainlandRealtimeProvider)? = nil,
        client: AMapClient? = nil
    ) -> any MainlandTransitProvider {
        let resolvedClient: AMapClient?
        if let client {
            resolvedClient = client
        } else {
            resolvedClient = try? AMapClient()
        }

        let baseFallback: any MainlandTransitProvider
        if let resolvedClient {
            let amap = AMapTransitProvider(
                client: resolvedClient,
                city: city,
                regionName: regionName
            )
            baseFallback = MainlandProviderRouter(primary: amap, fallback: fallback)
        } else {
            baseFallback = fallback
        }
        return MainlandProviderRouter(
            primary: primary,
            fallback: baseFallback,
            realtime: realtime
        )
    }

    static func amapOrFallback(
        city: MainlandCityIdentifier,
        regionName: String,
        fallback: any MainlandTransitProvider,
        realtime: (any MainlandRealtimeProvider)? = nil,
        client: AMapClient? = nil
    ) -> any MainlandTransitProvider {
        let resolvedClient: AMapClient?
        if let client {
            resolvedClient = client
        } else {
            resolvedClient = try? AMapClient()
        }

        guard let resolvedClient else { return fallback }
        let amap = AMapTransitProvider(
            client: resolvedClient,
            city: city,
            regionName: regionName
        )
        return MainlandProviderRouter(
            primary: amap,
            fallback: fallback,
            realtime: realtime
        )
    }
}
