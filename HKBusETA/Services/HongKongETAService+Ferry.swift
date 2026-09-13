import Foundation

extension HongKongETAService {
    /// Scheduled departures for ferries, derived from the route frequency table.
    static func ferryEtas(entry: RouteEntry, db: EtaDB, language: AppLanguage, limit: Int = 8) -> [Eta] {
        guard let freq = entry.freq, !freq.isEmpty else { return [] }
        let now = Date()
        let today = RegionClock.calendar.startOfDay(for: now)

        var departures: [Date] = []
        for dayOffset in -1...1 {
            guard let dayStart = RegionClock.calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let isHoliday = HongKongProvider().isHoliday(db, date: dayStart)
            let weekday = RegionClock.weekdayIndex(dayStart)

            for (serviceId, slots) in freq {
                guard let validDays = db.serviceDayMap[serviceId], !validDays.isEmpty else { continue }
                let valid: Bool
                if isHoliday {
                    valid = validDays.first == "1"
                } else {
                    valid = weekday < validDays.count && validDays[weekday] == "1"
                }
                guard valid else { continue }

                for (start, _) in slots {
                    let minutes = HongKongProvider.minutes(start)
                    let departure = dayStart.addingTimeInterval(TimeInterval(minutes * 60))
                    if departure > now {
                        departures.append(departure)
                    }
                }
            }
        }

        let unique = Array(Set(departures)).sorted().prefix(limit)
        return unique.map { date in
            Eta(
                eta: RegionClock.isoString(from: date),
                remark: Terminal(en: "", zh: ""),
                dest: entry.dest,
                co: entry.co.first ?? ""
            )
        }
    }
}
