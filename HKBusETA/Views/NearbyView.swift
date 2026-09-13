import CoreLocation
import SwiftUI
import UIKit

struct NearbyView: View {
    @Environment(AppState.self) private var app
    @State private var results: [NearbyStop] = []
    @State private var mainlandStops: [MainlandNearbyStop] = []
    @State private var isLoadingMainland = false
    @State private var mainlandError: String?

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
            .navigationDestination(for: MainlandLineTarget.self) { target in
                MainlandLineLoaderView(
                    lineId: target.lineId,
                    title: target.title,
                    seq: target.seq,
                    modeHint: target.modeHint,
                    origin: target.origin,
                    destination: target.destination,
                    firstDeparture: target.firstDeparture,
                    lastDeparture: target.lastDeparture,
                    fare: target.fare
                )
            }
            .navigationDestination(for: MainlandStopTarget.self) { target in
                MainlandStopBoardView(
                    stopID: target.stopID,
                    namesakeStopID: target.namesakeStopID,
                    title: target.title,
                    location: target.location
                )
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
        } else if app.mainlandProvider != nil {
            mainlandContent
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
    private var mainlandContent: some View {
        if app.location.location == nil || (isLoadingMainland && mainlandStops.isEmpty) {
            VStack(spacing: DesignTokens.Spacing.m) {
                ProgressView()
                    .tint(DesignTokens.accent)
                Text(L10n.t("nearby.locating"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let mainlandError {
            ContentUnavailableView {
                Label(L10n.t("error.mainland.requestFailed"), systemImage: "wifi.exclamationmark")
            } description: {
                Text(mainlandError)
            } actions: {
                Button(L10n.t("common.retry")) { recompute() }
            }
        } else if mainlandStops.isEmpty {
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
            List(mainlandStops) { stop in
                NavigationLink(value: MainlandStopTarget(
                    stopID: stop.stopID,
                    namesakeStopID: stop.namesakeStopID,
                    title: stop.name,
                    location: stop.location.map { StopLocation($0) }
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
                        if let distance = stop.distanceMeters {
                            Text("\(Int(distance.rounded())) m")
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

    private func arrivalSummary(_ arrivals: [MainlandNearbyArrival]) -> String {
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

        if let provider = app.mainlandProvider {
            isLoadingMainland = mainlandStops.isEmpty
            Task {
                do {
                    let stops = try await provider.nearby(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, limit: 20)
                    guard !Task.isCancelled else { return }
                    mainlandStops = stops
                    mainlandError = nil
                } catch is CancellationError {
                    return
                } catch {
                    mainlandStops = []
                    mainlandError = MainlandErrorPresentation.message(for: error)
                }
                isLoadingMainland = false
            }
            return
        }

        results = app.data.nearestStops(to: location, limit: 40)
    }
}
