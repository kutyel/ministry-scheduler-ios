//
//  MonthGrid.swift
//  ministry-scheduler
//

import Foundation

/// Pure calendar math for laying out one month as a 7-column grid.
/// Every cell has a globally unique, stable ID so lazy containers never
/// collide identities between padding cells and day cells.
struct MonthGrid {
    enum Cell: Identifiable, Equatable {
        case blank(index: Int)
        case day(Int)

        var id: String {
            switch self {
            case .blank(let index): return "blank-\(index)"
            case .day(let day): return "day-\(day)"
            }
        }
    }

    let year: Int
    let month: Int
    let daysInMonth: Int
    /// Number of empty cells before day 1 so it lands on its weekday column.
    let leadingBlanks: Int
    /// Weekday header symbols, rotated so the calendar's first weekday comes first.
    let weekdaySymbols: [String]
    /// All grid cells in order: leading blanks, then days 1...daysInMonth.
    let cells: [Cell]

    private let calendar: Calendar

    init(year: Int, month: Int, calendar: Calendar = .current) {
        self.year = year
        self.month = month
        self.calendar = calendar

        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        self.daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        self.leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        self.weekdaySymbols = Array(symbols[offset...] + symbols[..<offset])

        self.cells = (0..<leadingBlanks).map { .blank(index: $0) }
            + (1...daysInMonth).map { .day($0) }
    }

    var monthTitle: String {
        let date = calendar.date(from: DateComponents(year: year, month: month))!
        return date.formatted(.dateTime.month(.wide).year())
    }

    func isToday(day: Int, now: Date = .now) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        return comps.year == year && comps.month == month && comps.day == day
    }
}
