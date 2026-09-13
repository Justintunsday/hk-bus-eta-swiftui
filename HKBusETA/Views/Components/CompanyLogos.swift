import SwiftUI

/// Minimal operator glyphs (from the upstream hkbus project) shown after a
/// route number. Falls back to text tags for operators without a glyph.
struct CompanyLogos: View {
    @Environment(AppState.self) private var app
    let co: [String]
    let language: AppLanguage
    var height: CGFloat = 18

    var body: some View {
        HStack(spacing: 4) {
            if app.provider.id == "hk", co.contains("kmb"), co.contains("ctb") {
                logo("company_jointly")
            } else {
                ForEach(co, id: \.self) { raw in
                    if let op = app.provider.operators.op(raw) {
                        if let asset = op.logoAsset {
                            logo(asset)
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

    private func logo(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}
