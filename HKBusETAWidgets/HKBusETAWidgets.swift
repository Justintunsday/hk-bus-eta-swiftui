import SwiftUI
import WidgetKit
import AppIntents

@main
struct HKBusETAWidgetBundle: WidgetBundle {
    var body: some Widget {
        RouteCountdownWidget()
        SideStoreTransitWidget()
    }
}

struct RouteCountdownEntry: TimelineEntry {
    let date: Date
    let items: [WidgetPinnedItem]
}

struct WidgetFavoriteEntity: AppEntity, Hashable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "固定项目 / Pinned favorite"
    static let defaultQuery = WidgetFavoriteQuery()

    let id: String
    let title: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        if subtitle.isEmpty {
            return DisplayRepresentation(title: "\(title)")
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    init(_ item: WidgetPinnedItem) {
        id = item.id
        title = item.regionName.map { "\(item.title) · \($0)" } ?? item.title
        subtitle = item.arrivalLabel ?? item.destination
    }
}

struct WidgetFavoriteQuery: EntityQuery, Sendable {
    func entities(for identifiers: [WidgetFavoriteEntity.ID]) async throws -> [WidgetFavoriteEntity] {
        let requested = Set(identifiers)
        return WidgetSharedStore.load().items
            .filter { requested.contains($0.id) }
            .map(WidgetFavoriteEntity.init)
    }

    func suggestedEntities() async throws -> [WidgetFavoriteEntity] {
        WidgetSharedStore.load().items.map(WidgetFavoriteEntity.init)
    }
}

struct SelectWidgetFavoriteIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示收藏 / Displayed favorite"
    static var description = IntentDescription("选择 App 中已固定的线路或车站 / Choose a route or stop pinned from the app.")

    @Parameter(title: "线路或车站 / Route or stop")
    var favorite: WidgetFavoriteEntity?
}

struct RouteCountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RouteCountdownEntry {
        RouteCountdownEntry(
            date: Date(),
            items: [
                WidgetPinnedItem(
                    id: "sample",
                    kind: .route,
                    regionID: "hk",
                    regionName: "香港",
                    title: "73A",
                    origin: "愉翠苑",
                    destination: "粉嶺(華明)",
                    arrivalLabel: nil,
                    lineID: nil,
                    stopID: nil,
                    targetSequence: nil,
                    modeRawValue: nil,
                    etas: [Date().addingTimeInterval(180)],
                    updatedAt: Date()
                )
            ]
        )
    }

    func snapshot(
        for configuration: SelectWidgetFavoriteIntent,
        in context: Context
    ) async -> RouteCountdownEntry {
        currentEntry(configuration: configuration)
    }

    func timeline(
        for configuration: SelectWidgetFavoriteIntent,
        in context: Context
    ) async -> Timeline<RouteCountdownEntry> {
        let entry = currentEntry(configuration: configuration)
        let now = Date()
        let next = entry.items.compactMap { $0.etas.first }.filter { $0 > now }.min()
        let refresh = min(
            next?.addingTimeInterval(60) ?? now.addingTimeInterval(900),
            now.addingTimeInterval(900)
        )
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func currentEntry(configuration: SelectWidgetFavoriteIntent) -> RouteCountdownEntry {
        WidgetSharedStore.markWidgetAccess()
        let items = WidgetSharedStore.load().orderedByArrival
        if let selectedID = configuration.favorite?.id {
            return RouteCountdownEntry(date: Date(), items: items.filter { $0.id == selectedID })
        }
        return RouteCountdownEntry(date: Date(), items: items)
    }
}

struct RouteCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetSharedStore.widgetKind,
            intent: SelectWidgetFavoriteIntent.self,
            provider: RouteCountdownProvider()
        ) { entry in
            RouteCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.t("下一班", "Next Arrival"))
        .description(WidgetL10n.t("顯示收藏線路或車站的下一班到站時間。", "Next arrival for a pinned favorite route or stop."))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Views

struct RouteCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RouteCountdownEntry

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        content
            .widgetURL(URL(string: "wmbn://favorites"))
            .containerBackground(for: .widget) {
                if isAccessory {
                    Color.clear
                } else {
                    Color(uiColor: .systemBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let item = entry.items.first {
            switch family {
            case .accessoryCircular:
                AccessoryCircularView(item: item, date: entry.date)
            case .accessoryRectangular:
                AccessoryRectangularView(item: item, date: entry.date)
            case .accessoryInline:
                Text(inlineText(item))
            case .systemMedium:
                MediumView(items: Array(entry.items.prefix(3)), date: entry.date)
            default:
                SmallView(item: item, date: entry.date)
            }
        } else {
            EmptyPinView(family: family)
        }
    }

    private func inlineText(_ item: WidgetPinnedItem) -> String {
        guard let eta = item.nextArrival, eta > entry.date else {
            return "\(item.title) · \(WidgetL10n.t("等待更新", "no data"))"
        }
        let minutes = max(Int(ceil(eta.timeIntervalSince(entry.date) / 60)), 1)
        return "\(item.title) \(minutes) \(WidgetL10n.t("分鐘", "min"))"
    }
}

/// The app's signature countdown: tabular rounded numerals on the coral
/// accent, driven by WidgetKit's self-updating timer text.
private struct CountdownText: View {
    let date: Date
    let eta: Date?
    var size: CGFloat
    var color: Color = .primary

    var body: some View {
        Group {
            if let eta, eta > date {
                Text(timerInterval: date...eta, countsDown: true)
                    .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
            } else if eta != nil {
                Text(WidgetL10n.t("即將到站", "Due"))
                    .font(.system(size: size * 0.58, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            } else {
                Text("—")
                    .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.55)
    }
}
/// Small mode glyph for query-mode mainland lines (bus / metro).
private struct ModeGlyph: View {
    let modeRawValue: String?

    private var symbolName: String? {
        switch modeRawValue {
        case "metro": return "tram.fill"
        case "bus": return "bus.fill"
        default: return nil
        }
    }

    var body: some View {
        if let symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct SmallView: View {
    let item: WidgetPinnedItem
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                ModeGlyph(modeRawValue: item.modeRawValue)
                Text(item.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            Text(subtitle(item))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            CountdownText(date: date, eta: item.nextArrival, size: 36, color: WidgetAccent.color)
            updatedCaption(item)
        }
    }

    @ViewBuilder
    private func updatedCaption(_ item: WidgetPinnedItem) -> some View {
        if let updatedAt = item.updatedAt {
            Text(WidgetL10n.t("更新於 \(timeText(updatedAt))", "Updated \(timeText(updatedAt))"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            Text(WidgetL10n.t("開啟 App 以取得班次", "Open the app to refresh"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct MediumView: View {
    let items: [WidgetPinnedItem]
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    ModeGlyph(modeRawValue: item.modeRawValue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Text(subtitle(item))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    CountdownText(
                        date: date,
                        eta: item.nextArrival,
                        size: 22,
                        color: index == 0 ? WidgetAccent.color : .primary
                    )
                }
                .padding(.vertical, 5)
                if index < items.count - 1 {
                    Divider()
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct AccessoryCircularView: View {
    let item: WidgetPinnedItem
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(item.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            CountdownText(date: date, eta: item.nextArrival, size: 20, color: .primary)
        }
    }
}

private struct AccessoryRectangularView: View {
    let item: WidgetPinnedItem
    let date: Date

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.title) · \(subtitle(item))")
                    .font(.caption2)
                    .lineLimit(1)
                CountdownText(date: date, eta: item.nextArrival, size: 26, color: .primary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct EmptyPinView: View {
    let family: WidgetFamily

    var body: some View {
        if family == .accessoryInline {
            Text(WidgetL10n.t("未選擇收藏", "No pin"))
        } else {
            VStack(spacing: 3) {
                Image(systemName: "pin")
                    .font(.caption)
                Text(WidgetL10n.t("尚未選擇", "No pin yet"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if family != .accessoryCircular {
                    Text(WidgetL10n.t("在 App 收藏頁選擇線路或車站", "Pin a favorite in the app"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

private func subtitle(_ item: WidgetPinnedItem) -> String {
    switch item.kind {
    case .route:
        if let stopName = item.arrivalLabel, !stopName.isEmpty { return stopName }
        let destination = item.destination.isEmpty ? item.origin : item.destination
        return destination.isEmpty ? item.regionID.uppercased() : destination
    case .stop:
        guard let label = item.arrivalLabel, !label.isEmpty else {
            return WidgetL10n.t("等待更新", "waiting for update")
        }
        return "\(label) · \(WidgetL10n.t("即將到站", "arriving"))"
    }
}

private func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = WidgetL10n.isChinese ? Locale(identifier: "zh_Hant_HK") : Locale(identifier: "en_HK")
    formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}
