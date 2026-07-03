//
//  MonthGridTests.swift
//  ministry-schedulerTests
//

import Foundation
import Testing
@testable import ministry_scheduler

/// A fixed calendar so tests don't depend on the machine's locale or timezone.
private func gregorian(firstWeekday: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = firstWeekday
    return calendar
}

private let mondayFirst = gregorian(firstWeekday: 2)
private let sundayFirst = gregorian(firstWeekday: 1)

struct MonthGridTests {

    // MARK: - Month lengths

    @Test(arguments: [
        (month: 1, days: 31), (month: 2, days: 28), (month: 3, days: 31),
        (month: 4, days: 30), (month: 5, days: 31), (month: 6, days: 30),
        (month: 7, days: 31), (month: 8, days: 31), (month: 9, days: 30),
        (month: 10, days: 31), (month: 11, days: 30), (month: 12, days: 31),
    ])
    func monthLengths2026(month: Int, days: Int) {
        let grid = MonthGrid(year: 2026, month: month, calendar: mondayFirst)
        #expect(grid.daysInMonth == days)
    }

    @Test func leapYearFebruary() {
        #expect(MonthGrid(year: 2024, month: 2, calendar: mondayFirst).daysInMonth == 29)
        #expect(MonthGrid(year: 2028, month: 2, calendar: mondayFirst).daysInMonth == 29)
        #expect(MonthGrid(year: 2100, month: 2, calendar: mondayFirst).daysInMonth == 28)
    }

    // MARK: - Day 1 alignment

    // Known first weekdays: May 2026 = Friday, Feb 2027 = Monday, Mar 2026 = Sunday,
    // Nov 2026 = Sunday, Jul 2026 = Wednesday.
    @Test(arguments: [
        (year: 2026, month: 5, blanks: 4),   // Friday, Monday-first → Mon..Thu blank
        (year: 2027, month: 2, blanks: 0),   // Monday
        (year: 2026, month: 3, blanks: 6),   // Sunday
        (year: 2026, month: 11, blanks: 6),  // Sunday
        (year: 2026, month: 7, blanks: 2),   // Wednesday
    ])
    func leadingBlanksMondayFirst(year: Int, month: Int, blanks: Int) {
        let grid = MonthGrid(year: year, month: month, calendar: mondayFirst)
        #expect(grid.leadingBlanks == blanks)
    }

    @Test(arguments: [
        (year: 2026, month: 5, blanks: 5),   // Friday, Sunday-first → Sun..Thu blank
        (year: 2026, month: 3, blanks: 0),   // Sunday
        (year: 2026, month: 11, blanks: 0),  // Sunday
        (year: 2026, month: 7, blanks: 3),   // Wednesday
    ])
    func leadingBlanksSundayFirst(year: Int, month: Int, blanks: Int) {
        let grid = MonthGrid(year: year, month: month, calendar: sundayFirst)
        #expect(grid.leadingBlanks == blanks)
    }

    /// Day 1's column in the grid must match the actual weekday of the 1st.
    @Test func day1LandsOnItsWeekdayColumnForEveryMonth() {
        for calendar in [mondayFirst, sundayFirst] {
            for year in 2024...2028 {
                for month in 1...12 {
                    let grid = MonthGrid(year: year, month: month, calendar: calendar)
                    let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
                    let weekday = calendar.component(.weekday, from: first)
                    let expectedColumn = (weekday - calendar.firstWeekday + 7) % 7
                    #expect(grid.leadingBlanks == expectedColumn,
                            "\(year)-\(month) firstWeekday=\(calendar.firstWeekday)")
                }
            }
        }
    }

    // MARK: - Cell integrity

    /// Day 1 must always be present — this was the original bug (duplicate lazy-grid IDs hid it).
    @Test func everyMonthContainsAllDaysExactlyOnce() {
        for year in 2024...2028 {
            for month in 1...12 {
                let grid = MonthGrid(year: year, month: month, calendar: mondayFirst)
                let days = grid.cells.compactMap { cell -> Int? in
                    if case .day(let d) = cell { return d }
                    return nil
                }
                #expect(days == Array(1...grid.daysInMonth), "\(year)-\(month)")
            }
        }
    }

    @Test func allCellIDsAreUnique() {
        for year in 2024...2028 {
            for month in 1...12 {
                let grid = MonthGrid(year: year, month: month, calendar: mondayFirst)
                let ids = grid.cells.map(\.id)
                #expect(Set(ids).count == ids.count, "\(year)-\(month)")
            }
        }
    }

    @Test func cellCountIsBlanksPlusDays() {
        for month in 1...12 {
            let grid = MonthGrid(year: 2026, month: month, calendar: mondayFirst)
            #expect(grid.cells.count == grid.leadingBlanks + grid.daysInMonth)
            #expect(grid.leadingBlanks < 7)
        }
    }

    @Test func blanksComeBeforeAllDays() {
        let grid = MonthGrid(year: 2026, month: 5, calendar: mondayFirst)
        let firstDayIndex = grid.cells.firstIndex { if case .day = $0 { return true } else { return false } }
        #expect(firstDayIndex == grid.leadingBlanks)
        for (index, cell) in grid.cells.enumerated() {
            if case .blank = cell {
                #expect(index < grid.leadingBlanks)
            }
        }
    }

    // MARK: - Weekday header

    @Test func weekdaySymbolsStartAtCalendarFirstWeekday() {
        // en_US very short symbols: S M T W T F S (Sunday-indexed)
        #expect(MonthGrid(year: 2026, month: 1, calendar: sundayFirst).weekdaySymbols
                == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(MonthGrid(year: 2026, month: 1, calendar: mondayFirst).weekdaySymbols
                == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test func weekdaySymbolsAlwaysCountSeven() {
        #expect(MonthGrid(year: 2026, month: 6, calendar: mondayFirst).weekdaySymbols.count == 7)
    }

    // MARK: - Today detection

    @Test func isTodayMatchesOnlyTheActualDay() {
        let now = mondayFirst.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let july = MonthGrid(year: 2026, month: 7, calendar: mondayFirst)
        #expect(july.isToday(day: 3, now: now))
        #expect(!july.isToday(day: 4, now: now))
        let june = MonthGrid(year: 2026, month: 6, calendar: mondayFirst)
        #expect(!june.isToday(day: 3, now: now))
    }
}

struct ServiceYearTests {

    @Test func serviceYearBoundaries() {
        let calendar = mondayFirst
        // August 2026 belongs to the year that started Sept 2025.
        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        #expect(ServiceYear.startYear(containing: august, calendar: calendar) == 2025)
        // September 2026 starts a new service year.
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        #expect(ServiceYear.startYear(containing: september, calendar: calendar) == 2026)
    }

    @Test func serviceYearMonthsRunSeptemberToAugust() {
        let months = ServiceYear.months(startYear: 2025)
        #expect(months.count == 12)
        #expect(months.first! == (year: 2025, month: 9))
        #expect(months.last! == (year: 2026, month: 8))
        // Sept–Dec in the start year, Jan–Aug in the next.
        #expect(months.prefix(4).allSatisfy { $0.year == 2025 && $0.month >= 9 })
        #expect(months.suffix(8).allSatisfy { $0.year == 2026 && $0.month <= 8 })
    }
}

struct TimeFormatTests {

    @Test func formatting() {
        #expect(TimeFormat.hm(0) == "0h")
        #expect(TimeFormat.hm(45) == "45m")
        #expect(TimeFormat.hm(60) == "1h")
        #expect(TimeFormat.hm(210) == "3h 30m")
        #expect(TimeFormat.hm(3000) == "50h")
    }
}
