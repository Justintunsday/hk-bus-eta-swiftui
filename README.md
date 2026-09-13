# Where My Bus Now (WMBN) · 1.0

![Build](https://github.com/Justintunsday/where-my-bus-now/actions/workflows/build.yml/badge.svg)

An unofficial, ad-free multi-region realtime bus ETA app built with SwiftUI.

Where My Bus Now started as a SwiftUI rewrite of [hkbus/hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta).
Since 1.0 it supports multiple regions: Hong Kong plus mainland Chinese
cities via the unofficial CheLaile data source. This is not an official app.

## Features

- **Region switching, auto-detected from your location**: Hong Kong, plus
  Shenzhen, Guangzhou, Shanghai, Beijing, Tianjin, Chongqing, Chengdu,
  Foshan, Qingdao, Shenyang, Nanjing and Xi'an
- Every region has its own independent data; search, nearby, favorites and
  history all follow the selected city
- **Hong Kong**: realtime arrivals for KMB, Citybus, NLB, green minibus,
  MTR Bus, Light Rail, MTR and ferries; route details with fares, service
  hours and headways
- **Mainland cities (CheLaile)**: keyword search (lines and stops), nearby
  stops with realtime arrivals, stop departure boards, line details with
  map + ordered stops, realtime ETAs
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
  - `CheLaileProvider`: no static database, all queries on demand;
    `CheLaileClient` implements MD5 signing and AES-256-ECB envelope
    decryption for the unofficial H5 API
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
- `HKBusETA/Services` — TransitProvider, HongKongProvider, CheLaileClient /
  CheLaileProvider, DataStore, ETA services, bookmarks, location
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

GitHub Actions (`macos-26` / Xcode 26.6) builds the simulator app, an
unsigned device archive and an IPA on every push.

## Data Sources

- Hong Kong ETA data: DATA.GOV.HK and operator APIs; routes, stops, fares
  and headways come from [HK Bus Crawling@2021](https://github.com/hkbus/hk-bus-crawling)
  (`https://data.hkbus.app/routeFareList.min.json`, ~8 MB, downloaded once on
  first launch, cached locally and checked for updates daily)
- Mainland cities: the unofficial CheLaile H5 API (see
  [PeanutSplash/chelaile-mcp](https://github.com/PeanutSplash/chelaile-mcp),
  MIT). It may break at any time; data is for reference only.
- Operator glyphs: from [hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta)
  `public/img` (GPL-3.0)

## Disclaimer

This is an unofficial project. Hong Kong data comes from public open data;
mainland cities use an unofficial API that may stop working at any time.
All arrival data is for reference only — always check with the operator.

## License

[GPL-3.0](LICENSE), matching the upstream
[hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) project.
