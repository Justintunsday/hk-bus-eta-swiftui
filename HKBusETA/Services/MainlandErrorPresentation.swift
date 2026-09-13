import Foundation

/// Converts typed provider failures into a concise message for query screens.
/// The concrete vendor is intentionally not referenced here; an AMap error,
/// legacy compatibility error, or future authorized-feed error can all pass
/// through the same UI boundary.
enum MainlandErrorPresentation {
    static func message(for error: Error) -> String {
        if let mainlandError = error as? MainlandProviderError {
            switch mainlandError {
            case .noData:
                return L10n.t("mainland.metroPayloadUnavailable")
            default:
                break
            }
        }
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty,
              description != "The operation couldn’t be completed." else {
            return L10n.t("error.mainland.requestFailed")
        }
        return description
    }
}

extension MainlandDataSource {
    var localizedName: String {
        switch self {
        case .amapBase: return L10n.t("mainland.source.amap")
        case .authorizedRealtime: return L10n.t("mainland.source.authorizedRealtime")
        case .legacyFallback: return L10n.t("mainland.source.legacy")
        case .composite: return L10n.t("mainland.source.composite")
        }
    }
}
