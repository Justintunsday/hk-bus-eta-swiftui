import Foundation

/// Everything region-specific behind a single interface.
///
/// The UI layer talks to the active provider instead of Hong Kong assumptions,
/// so supporting another region means implementing this protocol and its data
/// source, not editing views.
protocol TransitProvider: Sendable {
    /// Stable identifier, also used to namespace settings/favorites later.
    var id: String { get }
    /// Region name shown in settings.
    var regionName: String { get }
    /// Time zone used for all schedule and ETA math in this region.
    var timeZone: TimeZone { get }
    /// Operators of this region.
    var operators: OperatorRegistry { get }

    // MARK: Data source

    /// Route/stop database URLs, in fallback order.
    var databaseURLs: [URL] { get }
    /// MD5 sidecar URLs matching `databaseURLs`.
    var databaseMd5URLs: [URL] { get }

    // MARK: Search filters

    func operatorIDs(for filter: TransportFilter) -> Set<String>

    // MARK: Schedule & fares

    func isHoliday(_ db: EtaDB, date: Date) -> Bool
    func isServiceAvailable(entry: RouteEntry, db: EtaDB, at date: Date) -> Bool
    func currentHeadway(entry: RouteEntry, db: EtaDB, at date: Date) -> Int?
    func serviceHoursToday(entry: RouteEntry, db: EtaDB, at date: Date) -> String?
    func fare(entry: RouteEntry, at index: Int, db: EtaDB, at date: Date) -> String?

    // MARK: Presentation

    /// Brand color used for a route's badge, map polyline and timeline.
    func routeColorHex(entry: RouteEntry) -> UInt32
    /// Minutes remaining below which an arrival is shown as "arriving".
    func arrivingThreshold(operatorID: String) -> Int

    // MARK: ETA

    func fetchEtas(entry: RouteEntry, seq: Int, db: EtaDB, language: AppLanguage) async -> [Eta]
}
