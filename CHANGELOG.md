# Changelog

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
