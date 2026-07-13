//
//  MonthlyReportTests.swift
//  ministry-schedulerTests
//

import Testing
@testable import ministry_scheduler

struct MonthlyReportTests {

    private func makeEntries() -> [DayEntry] {
        [
            // Confirmed field service time.
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 120, actualMinutes: 90),
            DayEntry(year: 2026, month: 7, day: 2, plannedMinutes: 60, actualMinutes: 60),
            // Confirmed credited time.
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 240, actualMinutes: 240, category: .ldc),
            DayEntry(year: 2026, month: 7, day: 4, plannedMinutes: 60, actualMinutes: 30, category: .bethel),
            // Planned but unconfirmed — must not count.
            DayEntry(year: 2026, month: 7, day: 5, plannedMinutes: 300, category: .ldc),
            // Different month — must not count.
            DayEntry(year: 2026, month: 6, day: 1, plannedMinutes: 60, actualMinutes: 60, category: .bethel),
        ]
    }

    @Test func splitsConfirmedMinutesByCategory() {
        let report = MonthlyReport(year: 2026, month: 7, entries: makeEntries())
        #expect(report.fieldServiceMinutes == 150)
        #expect(report.ldcMinutes == 240)
        #expect(report.bethelMinutes == 30)
        #expect(report.creditedMinutes == 270)
        #expect(report.totalMinutes == 420)
    }

    @Test func reportTextSeparatesCreditedHours() {
        let report = MonthlyReport(year: 2026, month: 7, entries: makeEntries())
        let text = report.reportText
        #expect(text.contains("Hours: 2h 30m"))
        #expect(text.contains("Credited hours: 4h 30m"))
        #expect(text.contains("LDC: 4h"))
        #expect(text.contains("Bethel: 30m"))
        #expect(text.contains("iMinistry"))
    }

    @Test func reportTextOmitsEmptyCreditBreakdown() {
        let entries = [DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 60, actualMinutes: 60)]
        let text = MonthlyReport(year: 2026, month: 7, entries: entries).reportText
        #expect(!text.contains("LDC"))
        #expect(!text.contains("Bethel"))
    }

    @Test func categoryDefaultsToFieldServiceForUnknownRawValue() {
        let entry = DayEntry(year: 2026, month: 7, day: 1)
        entry.categoryRaw = "something-else"
        #expect(entry.category == .fieldService)
    }
}
