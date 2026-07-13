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
}

/// Opens the Hourglass app (or its web app as a fallback) so the report
/// can be pasted into the publisher's monthly report form.
enum HourglassIntegration {
    static let webAppURL = URL(string: "https://app.hourglass-app.com/")!
    /// Custom scheme of the Hourglass mobile app. Undocumented, so we
    /// always fall back to the web app if it can't be opened.
    static let appURL = URL(string: "hourglass://")!

    static func open() {
        UIApplication.shared.open(appURL) { success in
            if !success {
                UIApplication.shared.open(webAppURL)
            }
        }
    }
}
