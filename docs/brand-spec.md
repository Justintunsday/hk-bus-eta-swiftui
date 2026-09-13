# Brand Specification — HK Bus ETA (SwiftUI)

Design direction: **Warm Minimal** — soft warm neutrals, rounded surfaces,
restrained information density, one warm accent. Avoids generic transit-app
chrome while keeping outdoor readability and data density.

## Colors

### Primary Accent
- **Color**: Warm Coral
- **Hex**: `#E85D3A`
- **Usage**: selection, links, active states, the first ETA countdown, timeline highlight, favorite active

### Accent Soft
- **Hex**: `#FBE9E2` light / `#3B241C` dark
- **Usage**: selection backgrounds, inline badges

### Neutrals (warm undertone)
| Token           | Light Mode | Dark Mode | Usage                    |
| --------------- | ---------- | --------- | ------------------------ |
| Background      | `#FAF9F7`  | `#1C1C1E` | Screen background        |
| Surface         | `#FFFFFF`  | `#2C2C2E` | Cards, elevated surfaces |
| Surface Muted   | `#F2EFEB`  | `#242426` | Chips, inactive fills    |
| Text Primary    | `#1A1A1A`  | `#F2F2F7` | Main text                |
| Text Secondary  | `#6B6862`  | `#9A9A9E` | Subtitles, metadata      |
| Text Tertiary   | `#9A968F`  | `#6E6E73` | Hints, timestamps        |
| Divider         | `#E9E5E0`  | `#38383A` | Separators               |

### Functional Colors
Company brand colors (KMB red, Citybus yellow, GMB green, MTR line colors…)
remain functional identity colors for route badges, map polylines and timelines.
The app accent is reserved for interaction and selection, so the two never
compete.

## Typography

### Display / Numerals
- **Font**: SF Rounded (system, `design: .rounded`) — rounded terminals match the Warm Minimal philosophy and keep CJK body text clean
- **Usage**: route numbers, countdown minutes, board ETA columns

### Body
- **Font**: SF Pro (system default)
- **Usage**: all labels, stop names, Chinese text

### Type Scale
| Level        | Size  | Weight   | Font        |
| ------------ | ----- | -------- | ----------- |
| Display      | 44pt  | Bold     | SF Rounded  |
| Title        | 28pt  | Bold     | SF Rounded  |
| Heading      | 18pt  | Semibold | SF Pro      |
| Body         | 15pt  | Regular  | SF Pro      |
| Caption      | 12pt  | Regular  | SF Pro      |
| Footnote     | 11pt  | Regular  | SF Pro      |

Tabular numerals (`.monospacedDigit()`) are mandatory for ETA columns so the
minutes align vertically.

Note: serif display type (as suggested for Editorial directions) is deliberately
not used — at small CJK sizes it reduces scan speed for outdoor transit use.

## Spacing
- **Grid**: 8pt base (`4 / 8 / 16 / 24 / 32`)
- **Horizontal padding**: 16pt phone, 20-24pt tablet
- **Section spacing**: 24pt
- **Element spacing**: 8-16pt
- **Minimum tap target**: 44pt

## Corner Radius
| Level  | Value | Usage                |
| ------ | ----- | -------------------- |
| Small  | 8pt   | Chips, badges        |
| Medium | 12pt  | Inputs, inner panels |
| Large  | 16pt  | Cards, map container |
| XL     | 20pt  | Sheets               |

## Signature Details (one per screen)
| Screen          | Signature                                                        |
| --------------- | ---------------------------------------------------------------- |
| Route ETA       | 44pt rounded coral countdown numeral as the hero element          |
| Stop board      | Aligned tabular ETA column — every route scans like a departure board |
| Route detail    | Timeline with route-colored spine and map card with numbered pins |
| Search          | Route number monograms in company colors on warm surface cards    |
| Nearby          | Right-aligned tabular distance column                            |

## Motion
- Selection/expansion: `.snappy` spring
- Map camera: 0.35s ease-in-out
- No decorative animations — motion only confirms state changes

## Logo Usage
- App icon: white bus silhouette on warm coral-to-red gradient (native rounded-square mask)
- Minimum display size: 44×44pt
- Clear space: 16pt on all sides
