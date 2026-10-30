//
//  NWPublisherIntegrationTests.swift
//  ministry-schedulerTests
//

import Foundation
import Testing
@testable import ministry_scheduler

struct NWPublisherIntegrationTests {

    private func report(_ entries: [DayEntry], year: Int = 2026, month: Int = 7) -> MonthlyReport {
        MonthlyReport(year: year, month: month, entries: entries)
    }

    @Test func reportURLCarriesHoursCreditAndRemarks() {
        let url = NWPublisherIntegration.reportURL(for: report([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 120, actualMinutes: 90),
            DayEntry(year: 2026, month: 7, day: 2, plannedMinutes: 60, actualMinutes: 60),
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 240, actualMinutes: 240, category: .ldc),
            DayEntry(year: 2026, month: 7, day: 4, plannedMinutes: 60, actualMinutes: 30, category: .bethel),
        ]))

        #expect(url.absoluteString ==
            "https://nwpublisher.com/report/sharedInMinistry=true:hours=2.5:credit=5:remarks=Credit+30m+Bethel,+4h+LDC")
    }

    @Test func reportURLOmitsFieldServiceVariablesWithoutFieldServiceTime() {
        let url = NWPublisherIntegration.reportURL(for: report([
            DayEntry(year: 2026, month: 7, day: 3, plannedMinutes: 240, actualMinutes: 240, category: .ldc),
        ]))

        #expect(url.absoluteString == "https://nwpublisher.com/report/credit=4:remarks=Credit+4h+LDC")
    }

    @Test func reportURLOmitsCreditVariablesWithoutCreditedTime() {
        let url = NWPublisherIntegration.reportURL(for: report([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 60, actualMinutes: 50),
        ]))

        #expect(url.absoluteString == "https://nwpublisher.com/report/sharedInMinistry=true:hours=0.83")
    }

    @Test func reportURLIsEmptyForAnEmptyMonth() {
        let url = NWPublisherIntegration.reportURL(for: report([]))
        #expect(url.absoluteString == "https://nwpublisher.com/report/")
    }

    @Test func creditUnderHalfAnHourIsOnlyInTheRemarks() {
        let url = NWPublisherIntegration.reportURL(for: report([
            DayEntry(year: 2026, month: 7, day: 1, plannedMinutes: 20, actualMinutes: 20, category: .bethel),
        ]))

        #expect(url.absoluteString == "https://nwpublisher.com/report/remarks=Credit+20m+Bethel")
    }

    @Test func remarksDropColonsAndEscapeReservedCharacters() {
        #expect(NWPublisherIntegration.encodeRemarks("Credit: 4h LDC") == "Credit+4h+LDC")
        #expect(NWPublisherIntegration.encodeRemarks("抵算：伯特利4h") == "%E6%8A%B5%E7%AE%97+%E4%BC%AF%E7%89%B9%E5%88%A94h")
        #expect(NWPublisherIntegration.encodeRemarks("a+b=c/d") == "a%2Bb%3Dc%2Fd")
    }

    @Test func decimalHoursUseAtMostTwoPlaces() {
        #expect(NWPublisherIntegration.decimalHours(3000) == "50")
        #expect(NWPublisherIntegration.decimalHours(150) == "2.5")
        #expect(NWPublisherIntegration.decimalHours(80) == "1.33")
    }
}
