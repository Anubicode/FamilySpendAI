import Foundation

struct MonthInterval: Equatable {
    let start: Date
    let end: Date
}

struct CategoryBudgetStatus: Identifiable {
    let id = UUID()
    let category: BudgetCategoryName
    let budgeted: Decimal
    let spent: Decimal
    let remaining: Decimal
    let overBudgetAmount: Decimal

    var isOverBudget: Bool {
        overBudgetAmount > 0
    }
}

struct UpcomingBillSummary: Identifiable {
    let id = UUID()
    let name: String
    let amount: Decimal
    let dueDate: Date
}

struct BudgetDashboardData {
    let month: MonthInterval
    let paydays: [Date]
    let monthlyIncome: Decimal
    let fixedExpenses: Decimal
    let totalSpent: Decimal
    let variableSpending: Decimal
    let savingsProgress: Decimal
    let remainingBudget: Decimal
    let safeToSpendPerDay: Decimal
    let nextPayday: Date?
    let daysRemaining: Int
    let isThreePaycheckMonth: Bool
    let unnecessarySpending: Decimal
    let categoryStatuses: [CategoryBudgetStatus]
    let upcomingBills: [UpcomingBillSummary]
    let topCategories: [(BudgetCategoryName, Decimal)]
}

enum BudgetEngine {
    static func monthInterval(for date: Date, calendar: Calendar = .canadian) -> MonthInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? date
        return MonthInterval(start: start, end: end)
    }

    static func generatePaydays(
        firstKnownPayday: Date,
        in month: MonthInterval,
        payFrequency: PayFrequency,
        calendar: Calendar = .canadian
    ) -> [Date] {
        switch payFrequency {
        case .biweekly:
            return repeatingPaydays(firstKnownPayday: firstKnownPayday, intervalDays: 14, in: month, calendar: calendar)
        case .weekly:
            return repeatingPaydays(firstKnownPayday: firstKnownPayday, intervalDays: 7, in: month, calendar: calendar)
        case .monthly:
            return monthlyPaydays(firstKnownPayday: firstKnownPayday, in: month, calendar: calendar)
        case .semiMonthly:
            return semiMonthlyPaydays(firstKnownPayday: firstKnownPayday, in: month, calendar: calendar)
        }
    }

    static func monthlyIncome(payAmount: Decimal, paydays: [Date]) -> Decimal {
        payAmount * Decimal(paydays.count)
    }

    static func discretionaryBudget(monthlyIncome: Decimal, fixedExpenses: Decimal) -> Decimal {
        monthlyIncome - fixedExpenses
    }

    static func remainingDiscretionaryBudget(
        monthlyIncome: Decimal,
        fixedExpenses: Decimal,
        spentSoFar: Decimal
    ) -> Decimal {
        discretionaryBudget(monthlyIncome: monthlyIncome, fixedExpenses: fixedExpenses) - spentSoFar
    }

    static func safeToSpendDaily(remainingDiscretionaryBudget: Decimal, remainingDaysInMonth: Int) -> Decimal {
        guard remainingDaysInMonth > 0 else { return 0 }
        return remainingDiscretionaryBudget / Decimal(remainingDaysInMonth)
    }

    static func categoryBudgetStatus(
        category: BudgetCategoryName,
        budgeted: Decimal,
        spent: Decimal
    ) -> CategoryBudgetStatus {
        let remaining = budgeted - spent
        let overBudgetAmount = max(Decimal.zero, spent - budgeted)
        return CategoryBudgetStatus(
            category: category,
            budgeted: budgeted,
            spent: spent,
            remaining: remaining,
            overBudgetAmount: overBudgetAmount
        )
    }

    static func isThreePaycheckMonth(paydays: [Date]) -> Bool {
        paydays.count == 3
    }

    static func nextPayday(
        after referenceDate: Date,
        firstKnownPayday: Date,
        payFrequency: PayFrequency,
        calendar: Calendar = .canadian
    ) -> Date? {
        switch payFrequency {
        case .biweekly:
            return nextRepeatingPayday(after: referenceDate, firstKnownPayday: firstKnownPayday, intervalDays: 14, calendar: calendar)
        case .weekly:
            return nextRepeatingPayday(after: referenceDate, firstKnownPayday: firstKnownPayday, intervalDays: 7, calendar: calendar)
        case .monthly:
            return nextMonthlyPayday(after: referenceDate, firstKnownPayday: firstKnownPayday, calendar: calendar)
        case .semiMonthly:
            return nextSemiMonthlyPayday(after: referenceDate, firstKnownPayday: firstKnownPayday, calendar: calendar)
        }
    }

    static func daysRemainingInMonth(from date: Date, calendar: Calendar = .canadian) -> Int {
        let startOfToday = calendar.startOfDay(for: date)
        let month = monthInterval(for: date, calendar: calendar)
        let startOfEnd = calendar.startOfDay(for: month.end)
        let diff = calendar.dateComponents([.day], from: startOfToday, to: startOfEnd).day ?? 0
        return max(1, diff + 1)
    }

    static func buildDashboard(
        referenceDate: Date,
        profile: UserProfile,
        transactions: [Transaction],
        budgetCategories: [BudgetCategory],
        recurringBills: [RecurringBill],
        calendar: Calendar = .canadian
    ) -> BudgetDashboardData {
        let month = monthInterval(for: referenceDate, calendar: calendar)
        let paydays = generatePaydays(
            firstKnownPayday: profile.firstKnownPayday,
            in: month,
            payFrequency: profile.payFrequency,
            calendar: calendar
        )

        let monthlyIncomeAmount = monthlyIncome(payAmount: Decimal(profile.biweeklyNetSalary), paydays: paydays)
        let recurringBillTotal = recurringBills
            .filter { $0.active }
            .reduce(Decimal.zero) { $0 + Decimal($1.amount) }
        let fixedExpensesAmount = Decimal(profile.rentOrMortgageAmount) + Decimal(profile.otherFixedMonthlyExpenses) + recurringBillTotal

        let monthTransactions = transactions.filter { calendar.isDate($0.date, equalTo: referenceDate, toGranularity: .month) }
        let totalSpentAmount = monthTransactions.reduce(Decimal.zero) { $0 + Decimal($1.amount) }
        let savingsProgress = monthTransactions
            .filter { $0.category == .savings }
            .reduce(Decimal.zero) { $0 + Decimal($1.amount) }
        let unnecessarySpending = monthTransactions
            .filter(\.isUnnecessary)
            .reduce(Decimal.zero) { $0 + Decimal($1.amount) }
        let variableSpendingAmount = monthTransactions
            .filter { $0.source != .recurringBill }
            .reduce(Decimal.zero) { $0 + Decimal($1.amount) }

        let remainingBudgetAmount = remainingDiscretionaryBudget(
            monthlyIncome: monthlyIncomeAmount,
            fixedExpenses: fixedExpensesAmount,
            spentSoFar: variableSpendingAmount
        )
        let daysRemaining = daysRemainingInMonth(from: referenceDate, calendar: calendar)
        let safeToSpend = safeToSpendDaily(
            remainingDiscretionaryBudget: remainingBudgetAmount,
            remainingDaysInMonth: daysRemaining
        )

        let spentByCategory = Dictionary(grouping: monthTransactions, by: \.category)
            .mapValues { group in
                group.reduce(Decimal.zero) { $0 + Decimal($1.amount) }
            }

        let statuses = budgetCategories
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { category in
                categoryBudgetStatus(
                    category: category.name,
                    budgeted: Decimal(category.monthlyLimit),
                    spent: spentByCategory[category.name] ?? 0
                )
            }

        let currentMonth = calendar.component(.month, from: referenceDate)
        let currentYear = calendar.component(.year, from: referenceDate)
        let upcomingBills = recurringBills
            .filter { $0.active }
            .compactMap { bill -> UpcomingBillSummary? in
                var components = DateComponents(year: currentYear, month: currentMonth, day: min(max(1, bill.dueDay), 28))
                guard let dueDate = calendar.date(from: components) else { return nil }
                let adjustedDate = dueDate < calendar.startOfDay(for: referenceDate)
                    ? calendar.date(byAdding: .month, value: 1, to: dueDate) ?? dueDate
                    : dueDate
                components.day = nil
                return UpcomingBillSummary(name: bill.name, amount: Decimal(bill.amount), dueDate: adjustedDate)
            }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(5)
            .map { $0 }

        let topCategories = spentByCategory
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .prefix(5)
            .map { ($0.key, $0.value) }

        return BudgetDashboardData(
            month: month,
            paydays: paydays,
            monthlyIncome: monthlyIncomeAmount,
            fixedExpenses: fixedExpensesAmount,
            totalSpent: totalSpentAmount,
            variableSpending: variableSpendingAmount,
            savingsProgress: savingsProgress,
            remainingBudget: remainingBudgetAmount,
            safeToSpendPerDay: safeToSpend,
            nextPayday: nextPayday(
                after: referenceDate,
                firstKnownPayday: profile.firstKnownPayday,
                payFrequency: profile.payFrequency,
                calendar: calendar
            ),
            daysRemaining: daysRemaining,
            isThreePaycheckMonth: isThreePaycheckMonth(paydays: paydays),
            unnecessarySpending: unnecessarySpending,
            categoryStatuses: statuses,
            upcomingBills: upcomingBills,
            topCategories: topCategories
        )
    }

    private static func repeatingPaydays(
        firstKnownPayday: Date,
        intervalDays: Int,
        in month: MonthInterval,
        calendar: Calendar
    ) -> [Date] {
        var cursor = calendar.startOfDay(for: firstKnownPayday)
        let monthStart = calendar.startOfDay(for: month.start)
        let monthEnd = calendar.startOfDay(for: month.end)

        while cursor > monthStart {
            cursor = calendar.date(byAdding: .day, value: -intervalDays, to: cursor) ?? cursor
        }

        while cursor < monthStart {
            cursor = calendar.date(byAdding: .day, value: intervalDays, to: cursor) ?? cursor
        }

        var paydays: [Date] = []
        while cursor <= monthEnd {
            paydays.append(cursor)
            cursor = calendar.date(byAdding: .day, value: intervalDays, to: cursor) ?? cursor
        }
        return paydays
    }

    private static func monthlyPaydays(
        firstKnownPayday: Date,
        in month: MonthInterval,
        calendar: Calendar
    ) -> [Date] {
        let day = calendar.component(.day, from: firstKnownPayday)
        let daysInMonth = calendar.range(of: .day, in: .month, for: month.start)?.count ?? 28
        var components = calendar.dateComponents([.year, .month], from: month.start)
        components.day = min(day, daysInMonth)
        if let payday = calendar.date(from: components) {
            return [payday]
        }
        return []
    }

    private static func semiMonthlyPaydays(
        firstKnownPayday: Date,
        in month: MonthInterval,
        calendar: Calendar
    ) -> [Date] {
        let firstDay = calendar.component(.day, from: firstKnownPayday)
        let secondDay = min(firstDay + 14, calendar.range(of: .day, in: .month, for: month.start)?.count ?? 28)
        let days = [firstDay, secondDay]
        return days.compactMap { day in
            var components = calendar.dateComponents([.year, .month], from: month.start)
            components.day = day
            return calendar.date(from: components)
        }
    }

    private static func nextRepeatingPayday(
        after referenceDate: Date,
        firstKnownPayday: Date,
        intervalDays: Int,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: firstKnownPayday)
        let reference = calendar.startOfDay(for: referenceDate)
        if start >= reference {
            return start
        }

        let dayDifference = calendar.dateComponents([.day], from: start, to: reference).day ?? 0
        let intervalsPassed = dayDifference / intervalDays
        let candidate = calendar.date(byAdding: .day, value: intervalsPassed * intervalDays, to: start) ?? start
        if candidate >= reference {
            return candidate
        }
        return calendar.date(byAdding: .day, value: intervalDays, to: candidate) ?? candidate
    }

    private static func nextMonthlyPayday(
        after referenceDate: Date,
        firstKnownPayday: Date,
        calendar: Calendar
    ) -> Date? {
        let currentMonth = monthInterval(for: referenceDate, calendar: calendar)
        let currentCandidates = monthlyPaydays(firstKnownPayday: firstKnownPayday, in: currentMonth, calendar: calendar)
        if let current = currentCandidates.first, current >= calendar.startOfDay(for: referenceDate) {
            return current
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth.start) else { return nil }
        return monthlyPaydays(firstKnownPayday: firstKnownPayday, in: monthInterval(for: nextMonth, calendar: calendar), calendar: calendar).first
    }

    private static func nextSemiMonthlyPayday(
        after referenceDate: Date,
        firstKnownPayday: Date,
        calendar: Calendar
    ) -> Date? {
        let currentMonth = monthInterval(for: referenceDate, calendar: calendar)
        let candidates = semiMonthlyPaydays(firstKnownPayday: firstKnownPayday, in: currentMonth, calendar: calendar)
            .filter { $0 >= calendar.startOfDay(for: referenceDate) }
            .sorted()
        if let candidate = candidates.first {
            return candidate
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth.start) else { return nil }
        return semiMonthlyPaydays(firstKnownPayday: firstKnownPayday, in: monthInterval(for: nextMonth, calendar: calendar), calendar: calendar)
            .sorted()
            .first
    }
}

private extension Decimal {
    static func / (lhs: Decimal, rhs: Decimal) -> Decimal {
        var lhs = lhs
        var rhs = rhs
        var result = Decimal()
        NSDecimalDivide(&result, &lhs, &rhs, .bankers)
        return result
    }
}
