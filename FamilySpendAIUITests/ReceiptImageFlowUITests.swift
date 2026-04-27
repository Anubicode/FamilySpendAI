import XCTest

final class ReceiptImageFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWalmartReceiptImageFlow() throws {
        let app = makeApp()
        app.launch()

        openScanTab(in: app)
        XCTAssertTrue(app.buttons["scan.sampleReceipt.walmart"].waitForExistence(timeout: 5))
        addScreenshot(named: "scan-screen-sample-buttons", in: app)

        app.buttons["scan.sampleReceipt.walmart"].tap()

        XCTAssertTrue(app.textFields["receiptReview.merchantField"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForElementToAppear(app.textFields["receiptReview.totalField"], in: app, timeout: 8))
        addScreenshot(named: "receipt-review-walmart", in: app)

        let merchantField = app.textFields["receiptReview.merchantField"]
        let merchantValue = (merchantField.value as? String) ?? ""
        XCTAssertTrue(merchantValue.uppercased().contains("WALMART"))

        app.buttons["receiptReview.saveButton"].tap()

        openTransactionsTab(in: app)
        XCTAssertTrue(app.staticTexts["WALMART"].waitForExistence(timeout: 5))
        addScreenshot(named: "transactions-after-receipt-save", in: app)
    }

    func testMessyReceiptRequiresReview() throws {
        let app = makeApp()
        app.launch()

        openScanTab(in: app)
        XCTAssertTrue(app.buttons["scan.sampleReceipt.messyTotal"].waitForExistence(timeout: 5))
        app.buttons["scan.sampleReceipt.messyTotal"].tap()

        XCTAssertTrue(app.textFields["receiptReview.merchantField"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForLowConfidenceWarning(in: app, timeout: 5))
        XCTAssertTrue(app.buttons["receiptReview.saveButton"].exists)
        addScreenshot(named: "receipt-review-messy", in: app)

        app.buttons["receiptReview.saveButton"].tap()

        openTransactionsTab(in: app)
        XCTAssertTrue(app.staticTexts["MESSY RECEIPT"].waitForExistence(timeout: 5))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetData",
            "-seedSampleData",
            "-seedSampleReceipts"
        ]
        return app
    }

    private func openScanTab(in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons["Scan"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
    }

    private func openTransactionsTab(in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons["Transactions"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
    }

    private func addScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForElementToAppear(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if element.exists {
                return true
            }

            app.swipeUp()
        }

        return element.exists
    }

    private func waitForLowConfidenceWarning(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if lowConfidenceWarning(in: app).exists {
                return true
            }

            app.swipeUp()
        }

        return lowConfidenceWarning(in: app).exists
    }

    private func lowConfidenceWarning(in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@", "receiptReview.lowConfidenceWarning")
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }
}
