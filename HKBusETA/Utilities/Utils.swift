import CoreLocation
import Foundation
import SwiftUI

enum GeoUtils {
    static func distance(from a: StopLocation, to b: StopLocation) -> CLLocationDistance {
        CLLocation(latitude: a.lat, longitude: a.lng)
            .distance(from: CLLocation(latitude: b.lat, longitude: b.lng))
    }

    static func distance(from a: CLLocation, to b: StopLocation) -> CLLocationDistance {
        a.distance(from: CLLocation(latitude: b.lat, longitude: b.lng))
    }

    static func distanceString(_ meters: CLLocationDistance, language: AppLanguage) -> String {
        if meters < 1000 {
            return "\(Int(round(meters / 10) * 10)) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}

enum ServiceHours {
    /// Whether the route has service at the given moment, based on its frequency table.
    static func isAvailable(_ entry: RouteEntry, db: EtaDB, at now: Date = Date()) -> Bool {
        guard let freq = entry.freq, !freq.isEmpty else { return true }
        let holiday = HKTime.isHoliday(db.holidays, date: now)
        let components = HKTime.calendar.dateComponents([.hour, .minute], from: now)
        let target = (holiday ? 0 : HKTime.weekdayIndex(now)) * 1440
            + (components.hour ?? 0) * 60 + (components.minute ?? 0)

        var available = false
        for (serviceId, slots) in freq {
            guard let validDays = db.serviceDayMap[serviceId] else {
                available = true
                continue
            }
            for (dayIndex, valid) in validDays.enumerated() where valid == "1" {
                for (start, slot) in slots {
                    let startMinutes = dayIndex * 1440 + minutes(start)
                    let endMinutes = dayIndex * 1440 + minutes(slot?.end ?? start)
                    if isBetween(start: startMinutes, end: endMinutes, target: target) {
                        available = true
                    }
                }
            }
        }
        return available
    }

    static func minutes(_ hhmm: String) -> Int {
        let hour = Int(hhmm.prefix(2)) ?? 0
        let minute = Int(hhmm.dropFirst(2).prefix(2)) ?? 0
        return hour * 60 + minute
    }

    private static func isBetween(start: Int, end: Int, target: Int) -> Bool {
        if start - 60 <= target && target <= end + 60 { return true }
        let wholeWeek = 24 * 7 * 60
        if start - 60 <= target + wholeWeek && target + wholeWeek <= end + 60 { return true }
        return false
    }

    /// Active headway in seconds, if a frequency slot is effective now.
    static func currentHeadway(_ entry: RouteEntry, db: EtaDB, at now: Date = Date()) -> Int? {
        guard let freq = entry.freq, !freq.isEmpty else { return nil }
        let holiday = HKTime.isHoliday(db.holidays, date: now)
        let components = HKTime.calendar.dateComponents([.hour, .minute], from: now)
        let target = (holiday ? 0 : HKTime.weekdayIndex(now)) * 1440
            + (components.hour ?? 0) * 60 + (components.minute ?? 0)

        for (serviceId, slots) in freq {
            guard let validDays = db.serviceDayMap[serviceId] else { continue }
            let effectiveDays: [Int] = holiday
                ? (validDays.first == "1" ? [0] : [])
                : validDays.enumerated().compactMap { $0.element == "1" ? $0.offset : nil }
            for dayIndex in effectiveDays {
                for (start, slot) in slots {
                    guard let slot else { continue }
                    let startMinutes = dayIndex * 1440 + minutes(start)
                    let endMinutes = dayIndex * 1440 + minutes(slot.end)
                    if startMinutes <= target, target <= endMinutes {
                        return slot.headway
                    }
                }
            }
        }
        return nil
    }

    /// Service hour string for today, e.g. "05:30 - 00:30".
    static func hoursToday(_ entry: RouteEntry, db: EtaDB, at now: Date = Date()) -> String? {
        guard let freq = entry.freq, !freq.isEmpty else { return nil }
        let holiday = HKTime.isHoliday(db.holidays, date: now)
        let weekday = HKTime.weekdayIndex(now)
        var starts: [String] = []
        var ends: [String] = []
        for (serviceId, slots) in freq {
            guard let validDays = db.serviceDayMap[serviceId] else { continue }
            let valid = holiday ? validDays.first == "1" : validDays[weekday] == "1"
            guard valid else { continue }
            for (start, slot) in slots {
                starts.append(start)
                if let slot { ends.append(slot.end) }
            }
        }
        guard let minStart = starts.min(), let maxEnd = ends.max() else { return nil }
        return "\(format(minStart)) - \(format(maxEnd))"
    }

    private static func format(_ hhmm: String) -> String {
        let total = minutes(hhmm)
        let hour = (total / 60) % 24
        let minute = total % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

enum FareUtils {
    static func fare(_ entry: RouteEntry, at index: Int, db: EtaDB, at now: Date = Date()) -> String? {
        if HKTime.isHoliday(db.holidays, date: now),
           let holidayFares = entry.faresHoliday,
           index < holidayFares.count {
            return holidayFares[index]
        }
        if let fares = entry.fares, index < fares.count {
            return fares[index]
        }
        return nil
    }
}
