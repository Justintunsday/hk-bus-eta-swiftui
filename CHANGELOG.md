# Changelog

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
