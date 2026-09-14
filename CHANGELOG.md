# Changelog

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
