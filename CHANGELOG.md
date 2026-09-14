# Changelog

## 1.5.0 (build 12)

- Added a Home Screen and Lock Screen widget showing the next arrival for
  pinned favorite routes or stops:
  - Home Screen: small (one pin) and medium (up to three pins)
  - Lock Screen: circular, rectangular and inline accessory families
  - Tabular rounded countdowns on the app's coral accent with WidgetKit's
    self-updating timer text, bilingual strings, tap opens the app.
- Favorites page gains a swipe "pin to widget" action (up to three pins) with
  an inline pin indicator; route pins reuse the last viewed stop for that
  route.
- ETA screens (Hong Kong route/stop boards and mainland boards) refresh the
  pinned items' arrival times so the widget always carries the latest data
  the app has seen.
- Data is shared through the `group.app.hkbus.swiftui` App Group. Sideloading
  with a free Apple ID may not grant App Groups; in that case the widget
  shows its empty state.

## 1.4.3 (build 11)

- Added simple transit-mode icons for other-region lines: mainland search
  rows and route/ETA/recents/favorites now show a quiet bus or metro chip
  when no operator logo exists.
- Hong Kong ferry operators render a ferry glyph instead of a text name.

## 1.4.2 (build 10)

- Rewrote the favorites page with region-grouped sections: the region is now
  the section header (pin + kind + region + count) instead of a cramped
  third-line caption inside every row.
- Rows now show only destination, origin and operator logos with a clear
  typographic hierarchy; groups follow catalog order (Hong Kong first) and
  newest-first inside each group.
- Applied the swiftui-design-skill Warm Minimal pass to the favorites screen
  (design tokens, 8pt rhythm, one signature organising element).

## 1.4.1 (build 9)

- Updated the mainland integration to the documented hosted CheLaile API:
  `https://ts-api.tundrey.com/v1` is now the primary instance with
  `https://chelaile-api-server.vercel.app/v1` as an automatic fallback on
  transport and 5xx failures.
- Removed the reverse-engineered direct CheLaile client (MD5 signing + AES
  envelope) and its provider; all mainland queries now go through the
  documented hosted API.
- Simplified the mainland provider composition to hosted primary + optional
  AMap base data.
- CI drops the legacy client self-tests and adds a non-blocking hosted API
  reachability probe.
- Favorites now aggregate routes and stops from every saved transit region,
  with an explicit region label to prevent same-number services from mixing.
- Opening an out-of-region favorite switches to its owning transit system
  before resolving the route or station.
- Restored recent routes and stations on empty search screens outside Hong
  Kong, and persisted mainland line IDs so history survives app restarts.
- Added compatibility recovery for mainland favorites and history created by
  earlier versions that did not store a provider line ID.

## 1.4.0 (build 7)

- Replaced the mainland primary source with the hosted CheLaile `/v1` API for
  search, nearby stops, stop boards, line details and realtime ETAs.
- Kept `LegacyCheLaileProvider` as an eligible-failure fallback and retained
  optional AMap as official base data without mixing its IDs into hosted ETA
  requests.
- Added deterministic offline fixtures for direction flattening, physical
  stop IDs, `sId` realtime translation, WGS-84 coordinates, ETA mapping and
  400-vs-503 fallback behavior.
- Preserved each existing mainland region ID and its independent bookmark and
  recent-history namespace.

## 1.3.0 (build 6)

- Added station navigation from Hong Kong and mainland stop boards, route
  stop expansion, and mainland stop targets.
- WGS-84 stations open Apple Maps walking directions from the current
  location; GCJ-02 stations use the official AMap iOS walking URI without
  passing mainland coordinates to MapKit.
- Added localized map/AMap installation failure messages and offline coverage
  for navigation strategy selection and URI encoding.

## 1.2.0 (build 5)

- Mainland metro search results now load standard route details through the
  active provider, with complete stop order and available service metadata.
- Mainland search scopes now filter bus, metro, and unsupported Hong Kong-only
  transport categories consistently; metro results no longer show bus stops.
- Preserved metro mode through legacy line-detail fallback and disabled bus ETA
  requests for mainland metro routes with an explicit no-realtime message.

## 1.1.2 (build 4)

- Fixed the legacy mainland compatibility client incorrectly treating
  CheLaile's current `"00"` success status as an upstream service error.
- Added an offline envelope regression test covering current and historical
  success codes while continuing to reject genuine upstream failures.

## 1.1.1 (build 3)

- Isolated favorites and recent history by transit region so routes and stops
  from Hong Kong and individual mainland cities can never collide.
- Added a versioned bookmark storage format. Legacy unscoped records are
  preserved in the Hong Kong namespace because older data did not record a
  city and cannot be classified reliably after the fact.

## 1.1.0 (build 2)

- Added a vendor-neutral mainland transit capability layer and fallback router.
- Added optional AMap Web Service base-data integration for official route and
  stop search/detail endpoints.
- Kept CheLaile as an explicitly labeled legacy compatibility fallback and
  improved its HTTP, upstream-business-error and cancellation handling.
- Added explicit GCJ-02/WGS-84 coordinate tagging at the MapKit boundary.
- Added offline AMap JSON/fallback self-tests to GitHub Actions.
- Updated mainland region identifiers to prefer adcode/citycode while keeping
  existing city selections available.

## 1.0.0

- Initial multi-region SwiftUI release.
