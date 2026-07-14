//
//  HourglassReport.swift
//  iMinistry
//
//  Month-end report split into regular field service hours and
//  "Credited hours" (LDC + Bethel), matching the categories used by
//  Hourglass (hourglass-app.com) and other JW reporting apps.
//

import Foundation
import UIKit

/// Totals for one month, split the way reporting apps expect them:
/// regular field service time versus credited (LDC / Bethel) time.
struct MonthlyReport {
    let year: Int
    let month: Int
    let fieldServiceMinutes: Int
    let ldcMinutes: Int
    let bethelMinutes: Int

    var creditedMinutes: Int { ldcMinutes + bethelMinutes }
    var totalMinutes: Int { fieldServiceMinutes + creditedMinutes }

    /// Confirmed (actual) minutes only — planned time that was never
    /// confirmed is not reportable.
    init(year: Int, month: Int, entries: [DayEntry]) {
        let monthEntries = entries.filter { $0.year == year && $0.month == month }
        func spent(_ category: HourCategory) -> Int {
            monthEntries
                .filter { $0.category == category }
                .reduce(0) { $0 + ($1.actualMinutes ?? 0) }
        }
        self.year = year
        self.month = month
        self.fieldServiceMinutes = spent(.fieldService)
        self.ldcMinutes = spent(.ldc)
        self.bethelMinutes = spent(.bethel)
    }

    var monthName: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month))!
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// Plain-text report understood by any reporting app's share/paste flow.
    /// Hours go in the regular field, LDC + Bethel time in "Credited hours"
    /// (the "Credit" field in Hourglass).
    var reportText: String {
        var lines = [
            "Field Service Report — \(monthName)",
            "Hours: \(TimeFormat.hm(fieldServiceMinutes))",
            "Credited hours: \(TimeFormat.hm(creditedMinutes))",
        ]
        if ldcMinutes > 0 {
            lines.append("  • LDC: \(TimeFormat.hm(ldcMinutes))")
        }
        if bethelMinutes > 0 {
            lines.append("  • Bethel: \(TimeFormat.hm(bethelMinutes))")
        }
        lines.append("")
        lines.append("Sent from iMinistry")
        return lines.joined(separator: "\n")
    }

    /// Credited time as decimal hours, e.g. "33" or "10.5".
    var creditHoursValue: String {
        String(format: "%g", Double(creditedMinutes) / 60.0)
    }

    /// Human-readable breakdown of the credited time, e.g.
    /// "Credit: 33h Bethel, 10h LDC".
    var creditRemarks: String {
        var parts: [String] = []
        if bethelMinutes > 0 {
            parts.append("\(TimeFormat.hm(bethelMinutes)) Bethel")
        }
        if ldcMinutes > 0 {
            parts.append("\(TimeFormat.hm(ldcMinutes)) LDC")
        }
        return "Credit: " + parts.joined(separator: ", ")
    }
}

/// Submits the report to Hourglass through its universal report URL,
/// which opens the app on iOS/Android (or the web app otherwise) with
/// the monthly report form pre-filled.
enum HourglassIntegration {
    static let submitEndpoint = "https://app.hourglass-app.com/report/submit"

    /// month, year and minutes are required; minutes=1 means "shared in
    /// the ministry" when no field service time was recorded. Credited
    /// time goes in `credithours` and, labelled, in `remarks`.
    static func submitURL(for report: MonthlyReport) -> URL {
        var components = URLComponents(string: submitEndpoint)!
        let minutes = report.fieldServiceMinutes > 0 ? report.fieldServiceMinutes : 1
        var items = [
            URLQueryItem(name: "month", value: String(report.month)),
            URLQueryItem(name: "year", value: String(report.year)),
            URLQueryItem(name: "minutes", value: String(minutes)),
        ]
        if report.creditedMinutes > 0 {
            items.append(URLQueryItem(name: "credithours", value: report.creditHoursValue))
            items.append(URLQueryItem(name: "remarks", value: report.creditRemarks))
        }
        components.queryItems = items
        return components.url!
    }

    static func submit(_ report: MonthlyReport) {
        UIApplication.shared.open(submitURL(for: report))
    }
}
