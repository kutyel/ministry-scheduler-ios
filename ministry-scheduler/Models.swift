//
//  Models.swift
//  ministry-scheduler
//

import Foundation
import SwiftData

/// How the hours of a day count toward the monthly report.
/// LDC and Bethel time is reported to Hourglass (and similar apps) as
/// "Credited hours"; everything else is regular field service time.
enum HourCategory: String, CaseIterable, Codable {
    case fieldService
    case ldc
    case bethel

    var isCredited: Bool { self != .fieldService }

    var label: String {
        switch self {
        case .fieldService: return "Field service"
        case .ldc: return "LDC"
        case .bethel: return "Bethel"
        }
    }
}

/// Time planned (and optionally confirmed) for a single calendar day.
@Model
final class DayEntry {
    var year: Int
    var month: Int
    var day: Int
    var plannedMinutes: Int
    /// nil until the user confirms how much time was actually spent that day.
    var actualMinutes: Int?
    /// Raw value of `HourCategory`. Stored as a string with a default so
    /// existing stores migrate without data loss.
    var categoryRaw: String = HourCategory.fieldService.rawValue

    var category: HourCategory {
        get { HourCategory(rawValue: categoryRaw) ?? .fieldService }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        year: Int,
        month: Int,
        day: Int,
        plannedMinutes: Int = 0,
        actualMinutes: Int? = nil,
        category: HourCategory = .fieldService
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.plannedMinutes = plannedMinutes
        self.actualMinutes = actualMinutes
        self.categoryRaw = category.rawValue
    }
}

/// Hour goal for a specific month. Only created when the user overrides the default.
@Model
final class MonthGoal {
    var year: Int
    var month: Int
    var goalMinutes: Int

    static let defaultMinutes = 50 * 60

    init(year: Int, month: Int, goalMinutes: Int = MonthGoal.defaultMinutes) {
        self.year = year
        self.month = month
        self.goalMinutes = goalMinutes
    }
}

/// Hour goal for a service year (September of `startYear` through August of `startYear + 1`).
@Model
final class ServiceYearGoal {
    var startYear: Int
    var goalMinutes: Int

    static let defaultMinutes = 600 * 60

    init(startYear: Int, goalMinutes: Int = ServiceYearGoal.defaultMinutes) {
        self.startYear = startYear
        self.goalMinutes = goalMinutes
    }
}

enum TimeFormat {
    /// "3h 30m", "3h", "45m", "0h"
    static func hm(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        switch (h, m) {
        case (_, 0): return "\(h)h"
        case (0, _): return "\(m)m"
        default: return "\(h)h \(m)m"
        }
    }

    static func hours(_ minutes: Int) -> Double {
        Double(minutes) / 60.0
    }
}

enum ServiceYear {
    /// The service year (Sept–Aug) a given date belongs to, identified by its starting year.
    static func startYear(containing date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return comps.month! >= 9 ? comps.year! : comps.year! - 1
    }

    /// The 12 (year, month) pairs of a service year, September first.
    static func months(startYear: Int) -> [(year: Int, month: Int)] {
        (0..<12).map { offset in
            let month = (9 + offset - 1) % 12 + 1
            return (year: month >= 9 ? startYear : startYear + 1, month: month)
        }
    }
}
