import CoreLocation
import SwiftUI
import UIKit

struct NearbyView: View {
    @Environment(AppState.self) private var app
    @State private var results: [NearbyStop] = []
    @State private var chelaileStops: [CheLaileNearbyStop] = []
    @State private var isLoadingChelaile = false

    private var language: AppLanguage { L10n.language }

    var body: some View {
        NavigationStack {
            DataGate {
                content
            }
            .navigationTitle(L10n.t("nearby.title"))
            .navigationDestination(for: StopTarget.self) { target in
                StopEtaView(stopId: target.stopId)
            }
            .navigationDestination(for: RouteEtaTarget.self) { target in
                RouteEtaView(routeKey: target.routeKey, seq: target.seq)
            }
            .navigationDestination(for: CheLaileLineTarget.self) { target in
                CheLaileLineLoaderView(lineId: target.lineId, title: target.title, seq: target.seq)
            }
            .navigationDestination(for: CheLaileStopTarget.self) { target in
                CheLaileStopBoardView(physicalStId: target.physicalStId, namesakeStId: target.namesakeStId, title: target.title)
            }
        }
        .task {
            app.location.startUpdating()
            recompute()
        }
        .task(id: app.region.id) {
            recompute()
        }
        .onChange(of: app.location.location) {
            recompute()
        }
        .onChange(of: app.location.authorizationStatus) {
            recompute()
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.location.isDenied {
            ContentUnavailableView {
                Label(L10n.t("nearby.denied.title"), systemImage: "location.slash")
            } description: {
                Text(L10n.t("nearby.denied.message"))
            } actions: {
                Button(L10n.t("nearby.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if !app.location.isAuthorized {
            ContentUnavailableView {
                Label(L10n.t("nearby.permission.title"), systemImage: "location")
            } description: {
                Text(L10n.t("nearby.permission.message"))
            } actions: {
                Button(L10n.t("nearby.permission.button")) {
                    app.location.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
            }
        } else if app.region.isQueryMode {
            chelaileContent
        } else if app.location.location == nil || results.isEmpty {
            VStack(spacing: DesignTokens.Spacing.m) {
                ProgressView()
                    .tint(DesignTokens.accent)
                Text(L10n.t("nearby.locating"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(results) { entry in
                NavigationLink(value: StopTarget(stopId: entry.item.id)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.isChinese ? L10n.display(entry.item.nameZh) : entry.item.nameEn)
                            let count = app.data.routeCount(at: entry.item.id)
                            if count > 0 {
                                Text("\(count) \(L10n.t("unit.routes"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(GeoUtils.distanceString(entry.distance, language: language))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chelaileContent: some View {
        if app.location.location == nil || (isLoadingChelaile && chelaileStops.isEmpty) {
            VStack(spacing: DesignTokens.Spacing.m) {
                ProgressView()
                    .tint(DesignTokens.accent)
                Text(L10n.t("nearby.locating"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chelaileStops.isEmpty {
            ContentUnavailableView {
                Label(L10n.t("nearby.title"), systemImage: "mappin.slash")
            } description: {
                Text(L10n.t("nearby.locating"))
            } actions: {
                Button(L10n.t("common.retry")) {
                    recompute()
                }
            }
        } else {
            List(chelaileStops) { stop in
                NavigationLink(value: CheLaileStopTarget(
                    physicalStId: stop.physicalStId,
                    namesakeStId: stop.namesakeStId,
                    title: stop.name
                )) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.name)
                                .font(.body)
                            if !stop.arrivals.isEmpty {
                                Text(arrivalSummary(stop.arrivals))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if let distance = stop.distance {
                            Text("\(distance) m")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .refreshable { recompute() }
        }
    }

    private func arrivalSummary(_ arrivals: [CheLaileNearbyArrival]) -> String {
        arrivals.map { arrival in
            if let minutes = arrival.minutes {
                return "\(arrival.lineName) \(minutes)\(L10n.t("unit.minutes"))"
            }
            return arrival.lineName
        }
        .joined(separator: " · ")
    }

    private func recompute() {
        guard let location = app.location.location, app.data.db != nil else { return }

        if let provider = app.provider as? CheLaileProvider {
            isLoadingChelaile = chelaileStops.isEmpty
            Task {
                let stops = (try? await provider.nearby(lat: location.coordinate.latitude, lng: location.coordinate.longitude)) ?? []
                chelaileStops = stops
                isLoadingChelaile = false
            }
            return
        }

        results = app.data.nearestStops(to: location, limit: 40)
    }
}
