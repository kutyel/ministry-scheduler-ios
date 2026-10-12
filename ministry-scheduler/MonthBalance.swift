//
//  MonthBalance.swift
//  ministry-scheduler
//

import Foundation

/// How far the confirmed time of a month drifted from its schedule, and
/// where to make it up. Pure value type so the math is unit-testable.
///
/// Only confirmed days count toward the balance: a day with `actualMinutes`
/// is compared against its own `plannedMinutes`. Planned days in the past
/// that were never confirmed are reported as pending, not as missed time.
struct MonthBalance {
    let year: Int
    let month: Int

    /// Planned minutes of the days that are already confirmed.
    let confirmedPlannedMinutes: Int
    /// Actual minutes of the days that are already confirmed.
    let confirmedActualMinutes: Int
    /// Planned minutes of the days still ahead (today included while unconfirmed).
    let upcomingPlannedMinutes: Int
    /// Past days with planned time that were never confirmed.
    let pendingDays: [Int]
    /// Extra minutes to add per upcoming planned day to recover a deficit.
    /// Empty when on or ahead of schedule.
    let compensation: [Int: Int]
    /// Deficit that cannot be placed because no planned day is left this month.
    let uncompensatedMinutes: Int

    /// Positive when ahead of the schedule, negative when behind.
    var deviationMinutes: Int { confirmedActualMinutes - confirmedPlannedMinutes }

    /// Spent time plus everything still planned, including compensation.
    var projectedMinutes: Int {
        confirmedActualMinutes + upcomingPlannedMinutes + compensation.values.reduce(0, +)
    }

    /// "+30m" / "−1h 15m", for compact badges.
    static func signed(_ minutes: Int) -> String {
        (minutes < 0 ? "\u{2212}" : "+") + TimeFormat.hm(abs(minutes))
    }

    /// Granularity of compensation suggestions, matching the day editor picker.
    static let step = 5
    private static let maxDayMinutes = 24 * 60

    init(year: Int, month: Int, entries: [DayEntry], now: Date = .now, calendar: Calendar = .current) {
        self.year = year
        self.month = month

        let monthEntries = entries.filter { $0.year == year && $0.month == month }
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        // Compare (year, month, day) lexicographically against today.
        func isPast(_ day: Int) -> Bool {
            (year, month, day) < (today.year!, today.month!, today.day!)
        }

        var plannedDone = 0
        var actualDone = 0
        var upcoming: [DayEntry] = []
        var pending: [Int] = []
        for entry in monthEntries {
            if let actual = entry.actualMinutes {
                plannedDone += entry.plannedMinutes
                actualDone += actual
            } else if entry.plannedMinutes > 0 {
                if isPast(entry.day) {
                    pending.append(entry.day)
                } else {
                    upcoming.append(entry)
                }
            }
        }
        upcoming.sort { $0.day < $1.day }

        self.confirmedPlannedMinutes = plannedDone
        self.confirmedActualMinutes = actualDone
        self.upcomingPlannedMinutes = upcoming.reduce(0) { $0 + $1.plannedMinutes }
        self.pendingDays = pending.sorted()

        let (compensation, rest) = Self.spread(
            deficit: max(0, plannedDone - actualDone),
            over: upcoming.map { (day: $0.day, planned: $0.plannedMinutes) }
        )
        self.compensation = compensation
        self.uncompensatedMinutes = rest
    }

    /// Spreads a deficit evenly over the upcoming days in `step`-minute
    /// chunks, earliest days first, never pushing a day past 24 hours.
    /// Returns the extra minutes per day and whatever did not fit.
    static func spread(deficit: Int, over days: [(day: Int, planned: Int)]) -> ([Int: Int], Int) {
        guard deficit > 0 else { return ([:], 0) }
        // Round up so the whole deficit is covered.
        var chunks = (deficit + step - 1) / step
        var extra: [Int: Int] = [:]
        var progressed = true
        while chunks > 0 && progressed {
            progressed = false
            for d in days where chunks > 0 {
                let current = extra[d.day, default: 0]
                guard d.planned + current + step <= maxDayMinutes else { continue }
                extra[d.day] = current + step
                chunks -= 1
                progressed = true
            }
        }
        let placed = extra.values.reduce(0, +)
        return (extra, max(0, deficit - placed))
    }
}
