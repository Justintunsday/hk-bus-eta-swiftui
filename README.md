# Where My Bus Now (WMBN) · 1.1.2

![Build](https://github.com/Justintunsday/where-my-bus-now/actions/workflows/build.yml/badge.svg)

An unofficial, ad-free multi-region realtime bus ETA app built with SwiftUI.

Where My Bus Now started as a SwiftUI rewrite of [hkbus/hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta).
Since 1.1 it supports mainland Chinese cities with AMap official base data
when configured, plus an explicitly marked legacy compatibility fallback. This
is not an official app.

## Features

- **Region switching, auto-detected from your location**: Hong Kong, plus
  Shenzhen, Guangzhou, Shanghai, Beijing, Tianjin, Chongqing, Chengdu,
  Foshan, Qingdao, Shenyang, Nanjing and Xi'an
- Every region has its own independent data; search, nearby, favorites and
  history are stored in separate region namespaces and follow the selected city
- **Hong Kong**: realtime arrivals for KMB, Citybus, NLB, green minibus,
  MTR Bus, Light Rail, MTR and ferries; route details with fares, service
  hours and headways
- **Mainland cities**: AMap official line/stop search and line details when
  configured; nearby, stop boards and realtime ETAs use replaceable provider
  capabilities with the legacy CheLaile compatibility fallback retained
- Route detail: MapKit map (polyline, numbered stop pins, tap to sync),
  timeline of stops, tap a stop to expand inline arrivals
- Stop departure boards with aligned tabular ETA columns
- Nearby stops with distance, favorites for whole routes and stops, recents
- ETA display modes (clock time / minutes / both), scheduled-trip markers
- Traditional Chinese, Simplified Chinese and English
- iPhone and iPad, dark mode, iOS 26 Liquid Glass

## Architecture

- SwiftUI + `@Observable` (iOS 17+), no third-party dependencies
- **`TransitProvider` protocol**: everything region-specific (data source,
  time zone, operators, calendars, fares, colors, ETA fetching) lives behind
  one interface
  - `HongKongProvider`: static database (updated daily) + data.gov.hk
    operator ETA APIs
- `MainlandTransitProvider`: vendor-neutral search, nearby, stop-board,
  line-payload and ETA capabilities with `MainlandProviderRouter` fallback
  composition
  - `AMapTransitProvider`: official AMap Web Service base data only
  - `LegacyCheLaileProvider`: clearly marked, unofficial compatibility source
    used only when AMap is unavailable or a capability is unsupported
  - `MainlandRealtimeProvider`: replaceable boundary for an authorized ETA
    feed; AMap itself does not provide realtime bus arrivals
- `RegionCatalog`: bundled city list and "nearest city" auto-selection;
  `RegionClock` carries the active time zone
- Query-mode lines are synthesized into standard `RouteEntry` values and
  registered in `DataStore`, so the map / timeline / ETA screens are fully
  reused across regions
- **Liquid Glass**: built with the Xcode 26 / iOS 26 SDK, standard controls
  adopt Liquid Glass automatically on iOS 26+; custom controls use the
  `glassEffect` API (compiler-gated so Xcode 16 still builds)
- Xcode 16 synchronized folders (`PBXFileSystemSynchronizedRootGroup`) — new
  files need no `project.pbxproj` changes
- `HKBusETA/Models` — EtaDB, TransitOperator, TransitRegion
- `HKBusETA/Services` — TransitProvider, HongKongProvider, mainland provider
  protocols/routers, AMapClient/AMapTransitProvider, legacy client, DataStore,
  ETA services, bookmarks, location
- `HKBusETA/Views` — search, route, ETA, nearby, favorites, settings
- `docs/brand-spec.md` — Warm Minimal design system

## Build

Requirements: macOS + Xcode 26 (iOS 26 SDK for Liquid Glass; Xcode 16 also
builds, without the glass material).

```bash
git clone https://github.com/Justintunsday/where-my-bus-now.git
cd where-my-bus-now
open HKBusETA.xcodeproj
```

GitHub Actions (`macos-26` / Xcode 26.6) runs an offline mainland fixture
self-test, keeps the optional legacy network smoke test allowed to fail, then
builds the simulator app, an unsigned device archive and an IPA on every push.

## Data Sources

- Hong Kong ETA data: DATA.GOV.HK and operator APIs; routes, stops, fares
  and headways come from [HK Bus Crawling@2021](https://github.com/hkbus/hk-bus-crawling)
  (`https://data.hkbus.app/routeFareList.min.json`, ~8 MB, downloaded once on
  first launch, cached locally and checked for updates daily)
- Mainland base data: [AMap Bus Web Service](https://lbs.amap.com/api/webservice/guide/api-advanced/bus-inquiry)
  endpoints `v3/bus/linename`, `v3/bus/lineid`, `v3/bus/stopname` and
  `v3/bus/stopid`. Configure `AMAP_WEB_SERVICE_KEY` through the generated
  `Info.plist` build setting or the process environment; no key is stored in
  source code. AMap data is GCJ-02 and remains explicitly tagged at the
  MapKit boundary.
- Mainland realtime ETA: AMap does not provide it through these bus endpoints.
  Supply an authorized implementation of `MainlandRealtimeProvider` when one
  is available. Until then, the unofficial CheLaile H5 API (see
  [PeanutSplash/chelaile-mcp](https://github.com/PeanutSplash/chelaile-mcp),
  MIT) remains a clearly marked compatibility fallback and may break at any
  time.
- Operator glyphs: from [hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta)
  `public/img` (GPL-3.0)

## Disclaimer

This is an unofficial project. Hong Kong data comes from public open data;
mainland base data may come from AMap and legacy realtime data may come from an
unofficial API that can stop working at any time. All arrival data is for
reference only — always check with the operator.

## License

[GPL-3.0](LICENSE), matching the upstream
[hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) project.
