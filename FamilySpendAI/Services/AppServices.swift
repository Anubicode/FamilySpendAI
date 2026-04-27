import Foundation
import SwiftData

enum SampleDataService {
    static func ensureGlobalDefaults(in context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        if settings.isEmpty {
            context.insert(AppSettings())
        }

        let benchmarks = try context.fetch(FetchDescriptor<BenchmarkRecord>())
        if benchmarks.isEmpty {
            context.insert(
                BenchmarkRecord(
                    year: 2023,
                    geography: "Canada",
                    averageHouseholdSpending: 76_750,
                    shelterShare: 0.321,
                    transportationShare: 0.158,
                    foodShare: 0.157,
                    confidence: .rough
                )
            )
        }
    }

    static func ensureCategories(in context: ModelContext, profile: UserProfile) throws {
        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        if categories.isEmpty {
            for (index, category) in BudgetCategoryName.allCases.enumerated() {
                context.insert(
                    BudgetCategory(
                        name: category,
                        categoryType: category.defaultType,
                        monthlyLimit: defaultBudget(for: category, profile: profile),
                        sortOrder: index
                    )
                )
            }
        } else {
            for category in categories {
                category.categoryType = category.name.defaultType
                if category.monthlyLimit == 0 {
                    category.monthlyLimit = defaultBudget(for: category.name, profile: profile)
                }
                category.updatedAt = .now
            }
        }
    }

    static func defaultBudget(for category: BudgetCategoryName, profile: UserProfile) -> Double {
        switch category {
        case .housing:
            return profile.rentOrMortgageAmount
        case .groceries:
            return Double(profile.familySize) * 175
        case .restaurantsCoffee:
            return 150
        case .transportation:
            return 150
        case .gas:
            return 200
        case .utilities:
            return 200
        case .phoneInternet:
            return 150
        case .kids:
            return Double(profile.numberOfChildren) * 125
        case .healthPharmacy:
            return 75
        case .subscriptions:
            return 60
        case .clothing:
            return 75
        case .homeHousehold:
            return 100
        case .entertainment:
            return 100
        case .personalCare:
            return 75
        case .education:
            return 50
        case .gifts:
            return 50
        case .travel:
            return 100
        case .debtRepayment:
            return 0
        case .savings:
            return profile.monthlySavingsTarget
        case .miscellaneous:
            return 100
        }
    }
}

enum DataResetService {
    static func deleteAllData(in context: ModelContext) throws {
        try deleteAll(UserProfile.self, in: context)
        try deleteAll(BudgetMonth.self, in: context)
        try deleteAll(BudgetCategory.self, in: context)
        try deleteAll(Transaction.self, in: context)
        try deleteAll(Receipt.self, in: context)
        try deleteAll(ReceiptLineItem.self, in: context)
        try deleteAll(RecurringBill.self, in: context)
        try deleteAll(MerchantRule.self, in: context)
        try deleteAll(CategoryRule.self, in: context)
        try deleteAll(MonthlyInsight.self, in: context)
        try deleteAll(BenchmarkRecord.self, in: context)
        try deleteAll(AppSettings.self, in: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }
}

enum Formatters {
    static let currency: FloatingPointFormatStyle<Double>.Currency = .currency(code: "CAD").locale(Locale(identifier: "en_CA"))
    static let shortDate: Date.FormatStyle = .dateTime.year().month(.abbreviated).day().locale(Locale(identifier: "en_CA"))
    static let monthYear: Date.FormatStyle = .dateTime.year().month(.wide).locale(Locale(identifier: "en_CA"))

    static func currency(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return number.doubleValue.formatted(currency)
    }

    static func currency(_ value: Double) -> String {
        value.formatted(currency)
    }
}

extension Calendar {
    static var canadian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_CA")
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .current
        return calendar
    }
}
