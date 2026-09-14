import SwiftUI

/// Minimal operator glyphs (from the upstream hkbus project) shown after a
/// route number. Regions without operator logos fall back to a simple
/// transit-mode glyph; ferry operators get a ferry glyph instead of text.
struct CompanyLogos: View {
    @Environment(AppState.self) private var app
    let co: [String]
    let language: AppLanguage
    var height: CGFloat = 18
    /// Mode of a query-mode mainland line; used when `co` is empty.
    var mode: MainlandTransitMode?

    var body: some View {
        HStack(spacing: 4) {
            if app.provider.id == "hk", co.contains("kmb"), co.contains("ctb") {
                logo("company_jointly")
            } else if co.isEmpty {
                modeIcon
            } else {
                ForEach(co, id: \.self) { raw in
                    if let op = app.provider.operators.op(raw) {
                        if let asset = op.logoAsset {
                            logo(asset)
                        } else if op.isFerry {
                            RouteModeIcon(symbolName: "ferry.fill", size: iconSize, label: op.name(language))
                        } else {
                            Text(op.name(language))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modeIcon: some View {
        if let symbol = mode?.symbolName {
            RouteModeIcon(symbolName: symbol, size: iconSize)
        }
    }

    private var iconSize: CGFloat {
        max(height - 5, 9)
    }

    private func logo(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}
