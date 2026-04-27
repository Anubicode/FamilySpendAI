import Foundation
import Combine
import SwiftData

struct OnboardingDraft {
    var familySize: Int = 4
    var numberOfAdults: Int = 2
    var numberOfChildren: Int = 2
    var province: Province = .ontario
    var city: String = ""
    var biweeklyNetSalary: Double = 2_500
    var firstKnownPayday: Date = .now
    var rentOrMortgageAmount: Double = 2_000
    var otherFixedMonthlyExpenses: Double = 600
    var monthlySavingsTarget: Double = 400
    var mainGoal: FinancialGoal = .controlMonthlySpending

    var isValid: Bool {
        familySize > 0 &&
        numberOfAdults > 0 &&
        numberOfChildren >= 0 &&
        biweeklyNetSalary > 0 &&
        rentOrMortgageAmount >= 0 &&
        otherFixedMonthlyExpenses >= 0 &&
        monthlySavingsTarget >= 0 &&
        familySize == numberOfAdults + numberOfChildren
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var draft = OnboardingDraft()
    @Published var errorMessage: String?
    @Published var isSaving = false

    func save(in context: ModelContext) {
        guard draft.isValid else {
            errorMessage = "Please complete all required fields and make sure family size matches adults plus children."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let profile = UserProfile(
                familySize: draft.familySize,
                numberOfAdults: draft.numberOfAdults,
                numberOfChildren: draft.numberOfChildren,
                province: draft.province,
                city: draft.city.isEmpty ? nil : draft.city,
                biweeklyNetSalary: draft.biweeklyNetSalary,
                firstKnownPayday: draft.firstKnownPayday,
                rentOrMortgageAmount: draft.rentOrMortgageAmount,
                otherFixedMonthlyExpenses: draft.otherFixedMonthlyExpenses,
                monthlySavingsTarget: draft.monthlySavingsTarget,
                mainGoal: draft.mainGoal
            )

            context.insert(profile)
            try SampleDataService.ensureGlobalDefaults(in: context)
            try SampleDataService.ensureCategories(in: context, profile: profile)
            try context.save()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save onboarding data. \(error.localizedDescription)"
        }
    }
}

struct TransactionDraft {
    var amount: Double = 0
    var date: Date = .now
    var merchant: String = ""
    var note: String = ""
    var category: BudgetCategoryName = .groceries
    var paymentMethod: PaymentMethod = .debit
    var isRecurring = false
    var isUnnecessary = false

    var isValid: Bool {
        amount > 0 && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
final class TransactionEditorViewModel: ObservableObject {
    @Published var draft = TransactionDraft()
    @Published var errorMessage: String?

    func save(in context: ModelContext, categoryLookup: [BudgetCategory]) -> Bool {
        guard draft.isValid else {
            errorMessage = "Enter an amount and merchant name before saving."
            return false
        }

        let matchedCategory = categoryLookup.first { $0.name == draft.category }
        let categoryType = matchedCategory?.categoryType ?? draft.category.defaultType
        let source: TransactionSource = draft.isRecurring ? .recurringBill : .manual

        let transaction = Transaction(
            amount: draft.amount,
            date: draft.date,
            merchant: draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            note: draft.note,
            category: draft.category,
            categoryType: categoryType,
            paymentMethod: draft.paymentMethod,
            source: source,
            isUnnecessary: draft.isUnnecessary
        )
        context.insert(transaction)

        if draft.isRecurring {
            let dueDay = Calendar.canadian.component(.day, from: draft.date)
            let recurringBill = RecurringBill(
                name: draft.merchant,
                amount: draft.amount,
                category: draft.category,
                dueDay: dueDay,
                startDate: draft.date,
                reminderEnabled: false
            )
            context.insert(recurringBill)
        }

        do {
            try context.save()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Unable to save the transaction. \(error.localizedDescription)"
            return false
        }
    }
}

struct RecurringBillDraft {
    var name: String = ""
    var amount: Double = 0
    var category: BudgetCategoryName = .utilities
    var dueDay: Int = 1
    var frequency: RecurringFrequency = .monthly
    var reminderEnabled = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0 && (1...28).contains(dueDay)
    }
}

@MainActor
final class BillEditorViewModel: ObservableObject {
    @Published var draft = RecurringBillDraft()
    @Published var errorMessage: String?

    func save(in context: ModelContext) -> Bool {
        guard draft.isValid else {
            errorMessage = "Add a bill name, amount, and due day between 1 and 28."
            return false
        }

        let bill = RecurringBill(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: draft.amount,
            category: draft.category,
            frequency: draft.frequency,
            dueDay: draft.dueDay,
            startDate: .now,
            reminderEnabled: draft.reminderEnabled
        )
        context.insert(bill)

        do {
            try context.save()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Unable to save the recurring bill. \(error.localizedDescription)"
            return false
        }
    }
}

struct DashboardViewModel {
    func summary(
        profile: UserProfile,
        transactions: [Transaction],
        categories: [BudgetCategory],
        recurringBills: [RecurringBill],
        referenceDate: Date = .now
    ) -> BudgetDashboardData {
        BudgetEngine.buildDashboard(
            referenceDate: referenceDate,
            profile: profile,
            transactions: transactions,
            budgetCategories: categories,
            recurringBills: recurringBills
        )
    }
}
