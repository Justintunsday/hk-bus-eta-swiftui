import AppIntents
import SwiftUI
import WidgetKit

struct WidgetTransitTargetEntity: AppEntity, Hashable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "线路与车站 / Route & stop"
    static let defaultQuery = WidgetTransitTargetQuery()

    let id: String
    let record: WidgetTransitTargetRecord

    init(_ record: WidgetTransitTargetRecord) {
        self.id = record.id
        self.record = record
    }

    init?(id: String) {
        guard let record = WidgetTransitTargetRecord(id: id) else { return nil }
        self.init(record)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(record.cityName) [\(record.cityID)] · \(record.lineName)",
            subtitle: "\(record.directionText) · \(record.stopName)"
        )
    }
}

struct WidgetTransitTargetQuery: EntityStringQuery, Sendable {
    func entities(for identifiers: [WidgetTransitTargetEntity.ID]) async throws -> [WidgetTransitTargetEntity] {
        identifiers.compactMap(WidgetTransitTargetEntity.init(id:))
    }

    func entities(matching string: String) async throws -> [WidgetTransitTargetEntity] {
        await WidgetTransitTargetResolver()
            .targets(for: string)
            .map(WidgetTransitTargetEntity.init)
    }

    /// There is no App Group-backed default. The configuration UI asks the
    /// user to search with a city prefix, which keeps the entity portable in
    /// SideStore installations.
    func suggestedEntities() async throws -> [WidgetTransitTargetEntity] { [] }
}

struct SelectSideStoreTransitTargetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "线路与车站 / Route & stop"
    static var description = IntentDescription(
        "输入城市、线路和车站，例如“佛山 352”或“上海 71 人民广场”。 / Search with a city, route and optional stop, such as “佛山 352” or “上海 71 人民广场”."
    )

    @Parameter(title: "线路与车站 / Route & stop")
    var target: WidgetTransitTargetEntity?
}

struct SideStoreTransitEntry: TimelineEntry {
    let date: Date
    let target: WidgetTransitTargetRecord?
    let etas: [Date]
    let status: Status

    enum Status: Sendable, Equatable {
        case setup
        case ready
        case noData
        case unavailable
    }
}

struct SideStoreTransitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SideStoreTransitEntry {
        SideStoreTransitEntry(
            date: Date(),
            target: WidgetTransitTargetRecord(
                cityID: "034",
                cityName: "上海",
                lineID: "sample-71",
                lineName: "71",
                direction: 0,
                origin: "起点",
                destination: "人民广场",
                stopID: "sample-stop",
                stopName: "人民广场",
                stationID: "034-sample",
                stopSequence: 2,
                latitude: 31.2304,
                longitude: 121.4737
            ),
            etas: [Date().addingTimeInterval(180)],
            status: .ready
        )
    }

    func snapshot(
        for configuration: SelectSideStoreTransitTargetIntent,
        in context: Context
    ) async -> SideStoreTransitEntry {
        entry(for: configuration.target?.record, etas: [], status: configuration.target == nil ? .setup : .noData)
    }

    func timeline(
        for configuration: SelectSideStoreTransitTargetIntent,
        in context: Context
    ) async -> Timeline<SideStoreTransitEntry> {
        let target = configuration.target?.record
        guard let target else {
            let now = Date()
            return Timeline(
                entries: [entry(for: nil, etas: [], status: .setup)],
                policy: .after(now.addingTimeInterval(900))
            )
        }

        let result = await WidgetTransitTargetResolver().etaDates(for: target)
        let status: SideStoreTransitEntry.Status = result.unavailable
            ? .unavailable
            : result.dates.isEmpty ? .noData : .ready
        let now = Date()
        return Timeline(
            entries: [entry(for: target, etas: result.dates, status: status)],
            policy: .after(now.addingTimeInterval(900))
        )
    }

    private func entry(
        for target: WidgetTransitTargetRecord?,
        etas: [Date],
        status: SideStoreTransitEntry.Status
    ) -> SideStoreTransitEntry {
        SideStoreTransitEntry(date: Date(), target: target, etas: etas, status: status)
    }
}

struct SideStoreTransitWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "SideStoreTransitWidget",
            intent: SelectSideStoreTransitTargetIntent.self,
            provider: SideStoreTransitProvider()
        ) { entry in
            SideStoreTransitWidgetView(entry: entry)
        }
        .configurationDisplayName("线路与车站 / Route & stop")
        .description("不依赖 App Group 的城市线路到站小组件。 / A city route ETA widget that does not require App Group.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct SideStoreTransitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SideStoreTransitEntry

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        content
            .widgetURL(entry.target.map { URL(string: "wmbn://transit/\($0.id)") } ?? URL(string: "wmbn://search"))
            .containerBackground(for: .widget) {
                isAccessory ? Color.clear : Color(uiColor: .systemBackground)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let target = entry.target {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(target.lineName).font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1)
                    TransitCountdown(date: entry.date, eta: entry.etas.first, size: 20)
                }
            case .accessoryRectangular:
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(target.cityName) · \(target.lineName)").font(.caption2).lineLimit(1)
                        Text(target.stopName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        TransitStatusText(entry: entry, compact: true)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Text(inlineText(target))
            case .systemMedium:
                medium(target)
            default:
                small(target)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                Text(WidgetL10n.t("搜尋城市、線路與車站", "Search city, route & stop"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(WidgetL10n.t("例如：佛山 352", "Example: Foshan 352"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func small(_ target: WidgetTransitTargetRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(target.cityName) [\(target.cityID)]")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(target.lineName)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(target.directionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(target.stopName)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            TransitStatusText(entry: entry, compact: false)
        }
    }

    private func medium(_ target: WidgetTransitTargetRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(target.cityName) [\(target.cityID)]")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(target.lineName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            Text(target.directionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .lastTextBaseline) {
                Text(target.stopName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let eta = entry.etas.first {
                    TransitCountdown(date: entry.date, eta: eta, size: 28)
                } else {
                    TransitStatusText(entry: entry, compact: true)
                }
            }
            if entry.etas.count > 1 {
                Text(entry.etas.dropFirst().map { etaText($0) }.joined(separator: "  ·  "))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func inlineText(_ target: WidgetTransitTargetRecord) -> String {
        if let eta = entry.etas.first {
            let minutes = max(Int(ceil(eta.timeIntervalSince(entry.date) / 60)), 1)
            return "\(target.lineName) · \(target.stopName) \(minutes) \(WidgetL10n.t("分", "min"))"
        }
        return "\(target.lineName) · \(statusText(entry.status))"
    }

    private func etaText(_ date: Date) -> String {
        let minutes = max(Int(ceil(date.timeIntervalSince(entry.date) / 60)), 1)
        return "\(minutes)\(WidgetL10n.t("分", "m"))"
    }

    private func statusText(_ status: SideStoreTransitEntry.Status) -> String {
        switch status {
        case .setup: return WidgetL10n.t("請選擇", "Choose target")
        case .ready: return WidgetL10n.t("即將到站", "arriving")
        case .noData: return WidgetL10n.t("暫無 ETA", "No ETA")
        case .unavailable: return WidgetL10n.t("暫時無法更新", "Unable to update")
        }
    }
}

private struct TransitCountdown: View {
    let date: Date
    let eta: Date?
    let size: CGFloat

    var body: some View {
        if let eta, eta > date {
            Text(timerInterval: date...eta, countsDown: true)
                .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(WidgetAccent.color)
                .lineLimit(1)
        } else {
            Text(WidgetL10n.t("暫無 ETA", "No ETA"))
                .font(.system(size: max(size * 0.45, 12), weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct TransitStatusText: View {
    let entry: SideStoreTransitEntry
    let compact: Bool

    var body: some View {
        if let eta = entry.etas.first {
            TransitCountdown(date: entry.date, eta: eta, size: compact ? 23 : 35)
        } else {
            Text(statusText)
                .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(entry.status == .unavailable ? Color.secondary : WidgetAccent.color)
                .lineLimit(1)
        }
    }

    private var statusText: String {
        switch entry.status {
        case .setup: return WidgetL10n.t("請選擇目標", "Choose a target")
        case .ready: return WidgetL10n.t("即將到站", "Arriving")
        case .noData: return WidgetL10n.t("暫無 ETA", "No ETA")
        case .unavailable: return WidgetL10n.t("暫時無法更新", "Unable to update")
        }
    }
}
