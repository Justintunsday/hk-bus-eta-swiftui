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
        HStack(spacing: DesignTokens.Spacing.s) {
            if showCompany, let company = eta.company {
                Text(company.name(language))
                    .font(DesignTokens.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            if annotateScheduled && eta.isScheduled {
                Image(systemName: "calendar.badge.clock")
                    .font(DesignTokens.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            if showDestination, eta.co == "mtr", !eta.dest.name(language).isEmpty {
                Text(eta.dest.name(language))
                    .font(DesignTokens.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            remarkText
            Spacer(minLength: DesignTokens.Spacing.xs)
            timeContent
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var remarkText: some View {
        let remark = eta.remark.name(language)
        if !remark.isEmpty, !eta.isScheduled {
            Text(remark)
                .font(DesignTokens.footnote)
                .foregroundStyle(DesignTokens.textTertiary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var timeContent: some View {
        if eta.date != nil, let minutes = eta.minutesUntil {
            switch format {
            case .exact:
                Text(HKTime.timeString(eta.eta))
                    .font(DesignTokens.tabular(17, weight: highlight ? .bold : .medium))
                    .foregroundStyle(highlight ? DesignTokens.accent : DesignTokens.textPrimary)
            case .diff:
                if isArriving(minutes) {
                    arrivingText
                } else {
                    minutesWithUnit(minutes)
                }
            case .mixed:
                HStack(spacing: DesignTokens.Spacing.s) {
                    Text(HKTime.timeString(eta.eta))
                        .font(DesignTokens.tabular(14, weight: .regular))
                        .foregroundStyle(DesignTokens.textTertiary)
                    if isArriving(minutes) {
                        arrivingText
                    } else {
                        minutesWithUnit(minutes)
                    }
                }
            }
        } else {
            Text(eta.remark.name(language))
                .font(DesignTokens.caption)
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private var arrivingText: some View {
        Text(L10n.t("eta.arriving"))
            .font(DesignTokens.subheading)
            .fontWeight(.semibold)
            .foregroundStyle(highlight ? DesignTokens.accent : DesignTokens.textPrimary)
    }

    private func minutesWithUnit(_ minutes: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
            Text("\(minutes)")
                .font(DesignTokens.tabular(20, weight: .bold))
            Text(L10n.t("unit.minutes"))
                .font(DesignTokens.footnote)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .foregroundStyle(highlight ? DesignTokens.accent : DesignTokens.textPrimary)
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
        HStack(spacing: DesignTokens.Spacing.xs) {
            if annotateScheduled && eta.isScheduled {
                Image(systemName: "calendar.badge.clock")
                    .font(DesignTokens.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            if eta.date != nil, let minutes = eta.minutesUntil {
                if format != .diff {
                    Text(HKTime.timeString(eta.eta))
                        .font(DesignTokens.tabular(13, weight: .regular))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                if minutes < threshold {
                    Text(L10n.t("eta.arriving"))
                        .font(DesignTokens.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(highlight ? DesignTokens.accent : DesignTokens.textPrimary)
                } else {
                    Text("\(minutes)")
                        .font(DesignTokens.tabular(18, weight: .bold))
                        .foregroundStyle(highlight ? DesignTokens.accent : DesignTokens.textPrimary)
                    Text(L10n.t("unit.minutes"))
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            } else {
                Text(eta.remark.name(language).isEmpty ? L10n.t("eta.noEta") : eta.remark.name(language))
                    .font(DesignTokens.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
