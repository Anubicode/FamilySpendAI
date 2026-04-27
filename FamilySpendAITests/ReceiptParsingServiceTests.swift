import XCTest
@testable import FamilySpendAI

final class ReceiptParsingServiceTests: XCTestCase {
    private let parser = ReceiptParsingService()
    private let calendar = Calendar.canadian

    func testReceiptWithSubtotalTaxAndTotalChoosesFinalTotal() {
        let rawText = """
        Maple Market
        2026-04-18
        Subtotal 45.20
        HST 5.88
        Total 51.08
        """

        let draft = parser.parse(rawText: rawText)

        XCTAssertEqual(draft.subtotal ?? 0, 45.20, accuracy: 0.001)
        XCTAssertEqual(draft.tax ?? 0, 5.88, accuracy: 0.001)
        XCTAssertEqual(draft.total ?? 0, 51.08, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(draft.fieldConfidence.total, 0.85)
    }

    func testTaxIsNotChosenAsFinalTotal() {
        let rawText = """
        Corner Shop
        18/04/2026
        GST 1.25
        HST 2.75
        Subtotal 22.00
        Total 26.00
        """

        let draft = parser.parse(rawText: rawText)

        XCTAssertEqual(draft.tax ?? 0, 4.00, accuracy: 0.001)
        XCTAssertEqual(draft.total ?? 0, 26.00, accuracy: 0.001)
        XCTAssertNotEqual(draft.total, draft.tax)
    }

    func testTipStoresTipSeparately() {
        let rawText = """
        Family Bistro
        Apr 18 2026
        Subtotal 54.00
        Tax 7.02
        Tip 10.00
        Total 71.02
        """

        let draft = parser.parse(rawText: rawText)

        XCTAssertEqual(draft.tip ?? 0, 10.00, accuracy: 0.001)
        XCTAssertEqual(draft.total ?? 0, 71.02, accuracy: 0.001)
    }

    func testMultipleCurrencyValuesChooseCorrectLabeledTotal() {
        let rawText = """
        Downtown Grocer
        2026-04-18
        Apples 4.99
        Bread 3.49
        Subtotal 20.48
        Amount Paid 23.14
        Change 0.00
        """

        let draft = parser.parse(rawText: rawText)

        XCTAssertEqual(draft.total ?? 0, 23.14, accuracy: 0.001)
        XCTAssertGreaterThan(draft.fieldConfidence.total, 0.9)
    }

    func testNoClearTotalUsesFallbackWithLowConfidence() {
        let rawText = """
        Mystery Store
        18/04/2026
        Item A 4.50
        Item B 8.99
        Card 19.75
        """

        let draft = parser.parse(rawText: rawText)

        XCTAssertEqual(draft.total ?? 0, 19.75, accuracy: 0.001)
        XCTAssertLessThan(draft.fieldConfidence.total, 0.7)
        XCTAssertTrue(draft.requiresReview)
    }

    func testDateExtractionSupportsCanadianFormats() {
        let rawText = """
        Cafe du Nord
        27/04/2026
        Total 12.40
        """

        let draft = parser.parse(rawText: rawText)
        let expected = makeDate(2026, 4, 27)

        XCTAssertEqual(draft.transactionDate, expected)
    }

    func testMerchantExtractionUsesTopMeaningfulLine() {
        let rawText = """
        MAPLE GROVE SUPERMARKET
        123 QUEEN STREET
        Toronto ON
        2026-04-18
        Total 10.20
        """

        let draft = parser.parse(rawText: rawText)

        XCTAssertEqual(draft.merchantName, "MAPLE GROVE SUPERMARKET")
    }

    func testEmptyOCRTextFailsGracefullyAndRequiresReview() {
        let draft = parser.parse(rawText: "")

        XCTAssertEqual(draft.rawText, "")
        XCTAssertNil(draft.total)
        XCTAssertTrue(draft.requiresReview)
        XCTAssertEqual(draft.confidenceScore, 0)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(calendar: calendar, year: year, month: month, day: day)
        return components.date ?? .now
    }
}
