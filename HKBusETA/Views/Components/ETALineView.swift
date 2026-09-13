import SwiftUI

struct ETALineView: View {
    let eta: Eta
    let language: AppLanguage
    let format: EtaFormat
    let annotateScheduled: Bool
    var highlight: Bool = false
    var showCompany: Bool = false
    var showDestination: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showCompany, let company = eta.company {
                Text(company.name(language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if annotateScheduled && eta.isScheduled {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showDestination, eta.co == "mtr", !eta.dest.name(language).isEmpty {
                Text(eta.dest.name(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            remarkText
            Spacer(minLength: 4)
            timeContent
        }
    }

    @ViewBuilder
    private var remarkText: some View {
        let remark = eta.remark.name(language)
        if !remark.isEmpty, !eta.isScheduled {
            Text(remark)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var timeContent: some View {
        if eta.date != nil, let minutes = eta.minutesUntil {
            switch format {
            case .exact:
                Text(HKTime.timeString(eta.eta))
                    .fontWeight(highlight ? .semibold : .regular)
                    .monospacedDigit()
                    .foregroundStyle(highlight ? Color.accentColor : .primary)
            case .diff:
                HStack(spacing: 2) {
                    Text(minutesText(minutes)).fontWeight(.semibold).monospacedDigit()
                    Text(L10n.t("unit.minutes")).font(.caption2).foregroundStyle(.secondary)
                }
                .foregroundStyle(highlight ? Color.accentColor : .primary)
            case .mixed:
                HStack(spacing: 8) {
                    Text(HKTime.timeString(eta.eta)).foregroundStyle(.secondary).monospacedDigit()
                    Text(minutesText(minutes)).fontWeight(.semibold).monospacedDigit()
                        .foregroundStyle(highlight ? Color.accentColor : .primary)
                    Text(L10n.t("unit.minutes")).font(.caption2).foregroundStyle(.secondary)
                }
            }
        } else {
            Text(eta.remark.name(language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func minutesText(_ minutes: Int) -> String {
        let threshold = (eta.co == "mtr" || eta.co == "lightRail") ? 2 : 1
        if minutes < threshold {
            return L10n.t("eta.arriving")
        }
        return "\(minutes)"
    }
}
