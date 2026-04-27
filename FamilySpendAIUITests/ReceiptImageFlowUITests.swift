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
        XCTAssertTrue(app.textFields["receiptReview.totalField"].exists)
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
        XCTAssertTrue(app.otherElements["receiptReview.lowConfidenceWarning"].waitForExistence(timeout: 5))
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
}
