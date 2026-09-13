import SwiftUI

/// Minimal operator glyphs (from the upstream hkbus project) shown after a
/// route number. Falls back to text tags for operators without a glyph.
struct CompanyLogos: View {
    let co: [String]
    let language: AppLanguage
    var height: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    private static let assetMap: [String: String] = [
        "kmb": "company_kmb",
        "ctb": "company_ctb",
        "nlb": "company_nlb",
        "lrtfeeder": "company_lrtfeeder",
        "gmb": "company_gmb",
        "mtr": "company_mtr",
        "lightRail": "company_mtr",
    ]

    var body: some View {
        HStack(spacing: 4) {
            if co.contains("kmb"), co.contains("ctb") {
                logo("company_jointly")
            } else {
                ForEach(co, id: \.self) { raw in
                    if let asset = Self.assetMap[raw] {
                        logo(asset)
                    } else if let company = Company(rawValue: raw) {
                        Text(company.name(language))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
            .padding(2)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.92) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }
}
