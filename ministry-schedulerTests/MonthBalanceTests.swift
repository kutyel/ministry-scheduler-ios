//
//  MonthBalanceTests.swift
//  ministry-schedulerTests
//

import Foundation
import Testing
@testable import ministry_scheduler

struct MonthBalanceTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Noon on 2026-07-10 UTC.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12))!
    }

    private func balance(_ entries: [DayEntry]) -> MonthBalance {
        MonthBalance(year: 2026, month: 7, entries: entries, now: now, calendar: calendar)
    }

    @Test func deficitIsSpreadOverUpcomingPlannedDays() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 120, actualMinutes: 90),
            DayEntry(year: 2026, month: 7, day: 2, plannedMinutes: 60, actualMinutes: 60),
            DayEntry(year: 2026, month: 7, day: 12, plannedMinutes: 120),
            DayEntry(year: 2026, month: 7, day: 15, plannedMinutes: 60),
        ])
        #expect(b.deviationMinutes == -30)
        #expect(b.compensation == [12: 15, 15: 15])
        #expect(b.uncompensatedMinutes == 0)
        #expect(b.projectedMinutes == 150 + 180 + 30)
    }

    @Test func todayCountsAsUpcomingUntilConfirmed() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 60, actualMinutes: 50),
            DayEntry(year: 2026, month: 7, day: 10, plannedMinutes: 60),
        ])
        #expect(b.compensation == [10: 10])
    }

    @Test func pastUnconfirmedDaysArePendingNotMissed() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 60),
            DayEntry(year: 2026, month: 7, day: 5, plannedMinutes: 90),
        ])
        #expect(b.deviationMinutes == 0)
        #expect(b.pendingDays == [3, 5])
        #expect(b.compensation.isEmpty)
        #expect(b.upcomingPlannedMinutes == 0)
    }

    @Test func multipleTypesOnOneDayCountAsOnePendingDay() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 480, category: .bethel),
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 180),
        ])
        #expect(b.pendingDays == [3])
    }

    @Test func compensationRespectsTheCombinedDayLimit() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 60, actualMinutes: 30),
            DayEntry(year: 2026, month: 7, day: 12, plannedMinutes: 480, category: .bethel),
            DayEntry(year: 2026, month: 7, day: 12, plannedMinutes: 945),
        ])
        #expect(b.upcomingPlannedMinutes == 1425)
        #expect(b.compensation == [12: 15])
        #expect(b.uncompensatedMinutes == 15)
    }

    @Test func extraPlannedTimeCoversTheDeficit() {
        let entries = [
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 240, actualMinutes: 0),
            DayEntry(year: 2026, month: 7, day: 12, plannedMinutes: 480, category: .bethel),
            DayEntry(year: 2026, month: 7, day: 12, plannedMinutes: 240),
        ]
        let b = MonthBalance(year: 2026, month: 7, entries: entries, goalMinutes: 720, now: now, calendar: calendar)
        #expect(b.deviationMinutes == -240)
        #expect(b.compensation.isEmpty)
        #expect(b.coveredByPlanMinutes == 240)
        #expect(b.uncompensatedMinutes == 0)
    }

    @Test func partlyPlannedExtraLeavesTheRestToCompensate() {
        let entries = [
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 240, actualMinutes: 0),
            DayEntry(year: 2026, month: 7, day: 12, plannedMinutes: 600),
        ]
        let b = MonthBalance(year: 2026, month: 7, entries: entries, goalMinutes: 720, now: now, calendar: calendar)
        #expect(b.coveredByPlanMinutes == 120)
        #expect(b.compensation == [12: 120])
    }

    @Test func aheadOfScheduleNeedsNoCompensation() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 60, actualMinutes: 120),
            DayEntry(year: 2026, month: 7, day: 20, plannedMinutes: 60),
        ])
        #expect(b.deviationMinutes == 60)
        #expect(b.compensation.isEmpty)
    }

    @Test func deficitWithoutPlannedDaysIsUncompensated() {
        let b = balance([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 120, actualMinutes: 13),
        ])
        #expect(b.compensation.isEmpty)
        #expect(b.uncompensatedMinutes == 107)
    }

    @Test func spreadRoundsUpToStepAndRespectsDayLimit() {
        let (extra, rest) = MonthBalance.spread(
            deficit: 22,
            over: [(day: 1, planned: 60), (day: 2, planned: 24 * 60 - 5)]
        )
        // 22m rounds up to 25m: day 2 takes one step, day 1 the rest.
        #expect(extra == [1: 20, 2: 5])
        #expect(rest == 0)
    }

    @Test func spreadReportsWhatDoesNotFit() {
        let (extra, rest) = MonthBalance.spread(deficit: 30, over: [(day: 1, planned: 24 * 60 - 10)])
        #expect(extra == [1: 10])
        #expect(rest == 20)
    }

    @Test func signedFormatsBothDirections() {
        #expect(MonthBalance.signed(30) == "+30m")
        #expect(MonthBalance.signed(-75) == "\u{2212}1h 15m")
    }
}
