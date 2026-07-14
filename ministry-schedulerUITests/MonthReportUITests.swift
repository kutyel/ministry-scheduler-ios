//
//  MonthReportUITests.swift
//  ministry-schedulerUITests
//
//  End-to-end coverage of the calendar, the day editor and the month
//  report sheet. The app is launched with `--uitest` so it runs on a
//  throwaway in-memory store; `--uitest-seed` fills the current month
//  with known entries (2h 30m field service, 4h LDC, 30m Bethel).
//

import XCTest

final class MonthReportUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = seeded ? ["--uitest", "--uitest-seed"] : ["--uitest"]
        app.launch()
        return app
    }

    @MainActor
    private func openReportSheet(_ app: XCUIApplication) {
        let sendReport = app.buttons["Send report"]
        XCTAssertTrue(sendReport.waitForExistence(timeout: 5))
        sendReport.tap()
        XCTAssertTrue(app.staticTexts["Field service"].waitForExistence(timeout: 5))
    }

    // MARK: - Tabs

    @MainActor
    func testSwitchingBetweenCalendarAndYearTabs() throws {
        let app = launchApp(seeded: false)

        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Year"].tap()
        XCTAssertFalse(app.navigationBars["Schedule"].exists)

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Send report"].exists)
    }

    // MARK: - Report sheet

    @MainActor
    func testReportSheetShowsSeededTotalsSplitByCategory() throws {
        let app = launchApp(seeded: true)
        openReportSheet(app)

        // Titled with the displayed month.
        let title = Date.now.formatted(.dateTime.month(.wide).year())
        XCTAssertTrue(app.navigationBars[title].exists)

        // Seeded data: field 2h 30m, LDC 4h, Bethel 30m, credited 4h 30m.
        XCTAssertTrue(app.staticTexts["2h 30m"].exists)
        XCTAssertTrue(app.staticTexts["LDC"].exists)
        XCTAssertTrue(app.staticTexts["4h"].exists)
        XCTAssertTrue(app.staticTexts["Bethel"].exists)
        XCTAssertTrue(app.staticTexts["30m"].exists)
        XCTAssertTrue(app.staticTexts["Total credited"].exists)
        XCTAssertTrue(app.staticTexts["4h 30m"].exists)
    }

    @MainActor
    func testReportSheetOffersSendShareAndCopyActions() throws {
        let app = launchApp(seeded: true)
        openReportSheet(app)

        XCTAssertTrue(app.buttons["Send to Hourglass"].exists)
        XCTAssertTrue(app.buttons["Share report…"].exists)
        XCTAssertTrue(app.buttons["Copy report"].exists)

        // Copying must not dismiss the sheet or crash.
        app.buttons["Copy report"].tap()
        XCTAssertTrue(app.buttons["Send to Hourglass"].exists)

        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Send report"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReportSheetShowsZeroTotalsForEmptyMonth() throws {
        let app = launchApp(seeded: false)
        openReportSheet(app)

        // Field service, LDC, Bethel and Total credited are all 0h.
        XCTAssertEqual(app.staticTexts.matching(identifier: "0h").count, 4)
        XCTAssertTrue(app.buttons["Send to Hourglass"].exists)
    }

    // MARK: - Day editor feeding the report

    @MainActor
    func testConfirmedDayEntryShowsUpInReport() throws {
        let app = launchApp(seeded: false)
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))

        // Open the editor for day 10 (exists in every month).
        app.staticTexts["10"].tap()
        XCTAssertTrue(app.switches["Confirm time spent"].waitForExistence(timeout: 5))

        // Plan 2 hours...
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "2 h")

        // ...and confirm the time as spent.
        let confirmToggle = app.switches["Confirm time spent"]
        if !confirmToggle.isHittable { app.swipeUp() }
        confirmToggle.tap()
        app.buttons["Save"].tap()

        // The calendar reflects the confirmed time...
        XCTAssertTrue(app.staticTexts["Spent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2h"].firstMatch.exists)

        // ...and so does the month report.
        openReportSheet(app)
        XCTAssertTrue(app.staticTexts["2h"].firstMatch.exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "0h").count, 3)
    }
}
