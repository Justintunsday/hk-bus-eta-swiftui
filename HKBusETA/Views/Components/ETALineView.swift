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
        .lineLimit(1)
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
                if isArriving(minutes) {
                    arrivingText
                } else {
                    minutesWithUnit(minutes)
                }
            case .mixed:
                HStack(spacing: 8) {
                    Text(HKTime.timeString(eta.eta))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if isArriving(minutes) {
                        arrivingText
                    } else {
                        minutesWithUnit(minutes)
                    }
                }
            }
        } else {
            Text(eta.remark.name(language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var arrivingText: some View {
        Text(L10n.t("eta.arriving"))
            .fontWeight(.semibold)
            .foregroundStyle(highlight ? Color.accentColor : .primary)
    }

    private func minutesWithUnit(_ minutes: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(minutes)")
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(L10n.t("unit.minutes"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(highlight ? Color.accentColor : .primary)
    }

    private func isArriving(_ minutes: Int) -> Bool {
        minutes < threshold
    }

    private var threshold: Int {
        (eta.co == "mtr" || eta.co == "lightRail") ? 2 : 1
    }
}

/// Single-line compact ETA used by the stop departure board.
struct ETACompactLineView: View {
    let eta: Eta
    let format: EtaFormat
    let annotateScheduled: Bool
    var highlight: Bool = false

    private var language: AppLanguage { L10n.language }
    private var threshold: Int { (eta.co == "mtr" || eta.co == "lightRail") ? 2 : 1 }

    var body: some View {
        HStack(spacing: 4) {
            if annotateScheduled && eta.isScheduled {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if eta.date != nil, let minutes = eta.minutesUntil {
                if format != .diff {
                    Text(HKTime.timeString(eta.eta))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if minutes < threshold {
                    Text(L10n.t("eta.arriving"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(highlight ? Color.accentColor : .primary)
                } else {
                    Text("\(minutes)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(highlight ? Color.accentColor : .primary)
                    Text(L10n.t("unit.minutes"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(eta.remark.name(language).isEmpty ? L10n.t("eta.noEta") : eta.remark.name(language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
