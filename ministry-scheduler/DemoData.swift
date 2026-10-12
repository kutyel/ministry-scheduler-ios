//
//  DemoData.swift
//  ministry-scheduler
//
//  Realistic sample data for App Store screenshots. Launch with `--demo`
//  to use an in-memory store filled with a pioneer's year. These optional
//  launch arguments (read through UserDefaults) open a specific screen:
//
//    -demoTab year            open the Year tab
//    -demoServiceYear 2025    service year shown in the Year tab
//    -demoMonth 11            month shown in the Calendar tab (current year)
//    -demoReport YES          open the month report sheet
//    -demoDay 9               open the day editor for that day
//

import Foundation
import SwiftData

enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--demo") }

    private static var defaults: UserDefaults { .standard }
    private static func int(_ key: String) -> Int? {
        guard isEnabled, defaults.object(forKey: key) != nil else { return nil }
        return defaults.integer(forKey: key)
    }

    static var tab: String? { isEnabled ? defaults.string(forKey: "demoTab") : nil }
    static var serviceYear: Int? { int("demoServiceYear") }
    static var month: Int? { int("demoMonth") }
    static var day: Int? { int("demoDay") }
    static var opensReport: Bool { isEnabled && defaults.bool(forKey: "demoReport") }

    /// Weekly rhythm of a regular pioneer, in minutes per weekday (1 = Sunday).
    private static let weeklyPlan: [Int: Int] = [1: 150, 3: 180, 4: 120, 7: 240]

    /// Fills every month from the previous service year up to next month:
    /// past days confirmed with small drifts, the current month partly
    /// behind schedule, and next month planned only.
    static func seed(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        let startYear = ServiceYear.startYear(containing: now, calendar: calendar) - 1
        var months = ServiceYear.months(startYear: startYear) + ServiceYear.months(startYear: startYear + 1)
        // Stop after next month.
        let thisIndex = months.firstIndex { $0.year == today.year && $0.month == today.month }!
        months = Array(months[...(thisIndex + 1)])

        for (index, ym) in months.enumerated() {
            let first = calendar.date(from: DateComponents(year: ym.year, month: ym.month, day: 1))!
            let days = calendar.range(of: .day, in: .month, for: first)!.count
            let isCurrent = index == thisIndex
            let isFuture = index > thisIndex

            for day in 1...days {
                let date = calendar.date(from: DateComponents(year: ym.year, month: ym.month, day: day))!
                let weekday = calendar.component(.weekday, from: date)
                let isPast = !isFuture && (!isCurrent || day < today.day!)

                // One LDC Friday every other month, one Bethel Thursday each quarter.
                if weekday == 6 && day > 7 && day <= 14 && (index % 2 == 1 || isFuture) {
                    context.insert(DayEntry(year: ym.year, month: ym.month, day: day,
                                            plannedMinutes: 480, actualMinutes: isPast ? 480 : nil,
                                            category: .ldc))
                    continue
                }
                if weekday == 5 && day <= 7 && index % 3 == 1 {
                    context.insert(DayEntry(year: ym.year, month: ym.month, day: day,
                                            plannedMinutes: 180, actualMinutes: isPast ? 180 : nil,
                                            category: .bethel))
                    continue
                }
                guard let planned = weeklyPlan[weekday] else { continue }

                var actual: Int?
                if isPast {
                    actual = planned + drift(day: day, month: ym.month, current: isCurrent)
                }
                context.insert(DayEntry(year: ym.year, month: ym.month, day: day,
                                        plannedMinutes: planned, actualMinutes: actual))
            }
        }
        try? context.save()
    }

    /// Deterministic deviation from the plan. Past months mostly balance out;
    /// the current month ends up behind so the catch-up hints show.
    private static func drift(day: Int, month: Int, current: Bool) -> Int {
        if current {
            switch day % 7 {
            case 3: return -60
            case 6: return 30
            case 0: return -60
            default: return 0
            }
        }
        switch (day + month) % 9 {
        case 0: return -30
        case 4: return 30
        case 7: return 60
        default: return 0
        }
    }
}
