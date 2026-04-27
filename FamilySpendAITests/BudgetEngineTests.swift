import XCTest
@testable import FamilySpendAI

final class BudgetEngineTests: XCTestCase {
    private let calendar = Calendar.canadian

    func testGeneratePaydaysForTwoPaycheckMonth() {
        let month = BudgetEngine.monthInterval(for: makeDate(2026, 4, 10))
        let paydays = BudgetEngine.generatePaydays(
            firstKnownPayday: makeDate(2026, 4, 3),
            in: month,
            payFrequency: .biweekly,
            calendar: calendar
        )

        XCTAssertEqual(paydays, [makeDate(2026, 4, 3), makeDate(2026, 4, 17)])
    }

    func testMonthlyIncomeForTwoPaycheckMonth() {
        let paydays = [makeDate(2026, 4, 3), makeDate(2026, 4, 17)]
        let income = BudgetEngine.monthlyIncome(payAmount: 2_500, paydays: paydays)
        XCTAssertEqual(income, 5_000)
    }

    func testMonthlyIncomeForThreePaycheckMonth() {
        let paydays = [makeDate(2026, 1, 2), makeDate(2026, 1, 16), makeDate(2026, 1, 30)]
        let income = BudgetEngine.monthlyIncome(payAmount: 2_500, paydays: paydays)
        XCTAssertEqual(income, 7_500)
        XCTAssertTrue(BudgetEngine.isThreePaycheckMonth(paydays: paydays))
    }

    func testDiscretionaryBudgetAfterFixedExpenses() {
        let discretionary = BudgetEngine.discretionaryBudget(monthlyIncome: 5_000, fixedExpenses: 3_000)
        XCTAssertEqual(discretionary, 2_000)
    }

    func testSafeToSpendCalculation() {
        let value = BudgetEngine.safeToSpendDaily(remainingDiscretionaryBudget: 900, remainingDaysInMonth: 15)
        XCTAssertEqual(value, 60)
    }

    func testCategoryBudgetRemainingAndOverBudget() {
        let status = BudgetEngine.categoryBudgetStatus(category: .groceries, budgeted: 600, spent: 750)
        XCTAssertEqual(status.remaining, -150)
        XCTAssertEqual(status.overBudgetAmount, 150)
        XCTAssertTrue(status.isOverBudget)
    }

    func testNextBiweeklyPayday() {
        let payday = BudgetEngine.nextPayday(
            after: makeDate(2026, 4, 20),
            firstKnownPayday: makeDate(2026, 4, 3),
            payFrequency: .biweekly,
            calendar: calendar
        )
        XCTAssertEqual(payday, makeDate(2026, 5, 1))
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(calendar: calendar, year: year, month: month, day: day)
        return components.date ?? .now
    }
}
