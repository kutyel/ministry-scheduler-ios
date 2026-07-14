//
//  HourglassIntegrationTests.swift
//  ministry-schedulerTests
//

import Foundation
import Testing
@testable import ministry_scheduler

struct HourglassIntegrationTests {

    private func queryItems(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func submitURLCarriesMonthYearMinutesAndCredit() {
        let entries = [
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 120, actualMinutes: 90),
            DayEntry(year: 2026, month: 7, day: 2, plannedMinutes: 60, actualMinutes: 60),
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 240, actualMinutes: 240, category: .ldc),
            DayEntry(year: 2026, month: 7, day: 4, plannedMinutes: 60, actualMinutes: 30, category: .bethel),
        ]
        let report = MonthlyReport(year: 2026, month: 7, entries: entries)
        let url = HourglassIntegration.submitURL(for: report)

        #expect(url.absoluteString.hasPrefix("https://app.hourglass-app.com/report/submit?"))
        let params = queryItems(of: url)
        #expect(params["month"] == "7")
        #expect(params["year"] == "2026")
        #expect(params["minutes"] == "150")
        #expect(params["credithours"] == "4.5")
        #expect(params["remarks"] == "Credit: 30m Bethel, 4h LDC")
    }

    @Test func submitURLUsesOneMinuteToMarkSharingWithoutFieldServiceTime() {
        let entries = [
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 240, actualMinutes: 240, category: .ldc),
        ]
        let report = MonthlyReport(year: 2026, month: 7, entries: entries)
        let params = queryItems(of: HourglassIntegration.submitURL(for: report))

        #expect(params["minutes"] == "1")
        #expect(params["credithours"] == "4")
        #expect(params["remarks"] == "Credit: 4h LDC")
    }

    @Test func submitURLOmitsCreditParametersWithoutCreditedTime() {
        let entries = [
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 60, actualMinutes: 60),
        ]
        let report = MonthlyReport(year: 2026, month: 7, entries: entries)
        let params = queryItems(of: HourglassIntegration.submitURL(for: report))

        #expect(params["minutes"] == "60")
        #expect(params["credithours"] == nil)
        #expect(params["remarks"] == nil)
    }

    @Test func creditHoursValueUsesDecimalHours() {
        func report(ldcMinutes: Int) -> MonthlyReport {
            MonthlyReport(year: 2026, month: 7, entries: [
                DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: ldcMinutes, actualMinutes: ldcMinutes, category: .ldc),
            ])
        }
        #expect(report(ldcMinutes: 120).creditHoursValue == "2")
        #expect(report(ldcMinutes: 150).creditHoursValue == "2.5")
        #expect(report(ldcMinutes: 45).creditHoursValue == "0.75")
    }
}
