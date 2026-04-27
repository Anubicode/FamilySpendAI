import Foundation
import SwiftData

enum Province: String, CaseIterable, Codable, Identifiable {
    case alberta = "Alberta"
    case britishColumbia = "British Columbia"
    case manitoba = "Manitoba"
    case newBrunswick = "New Brunswick"
    case newfoundlandAndLabrador = "Newfoundland and Labrador"
    case northwestTerritories = "Northwest Territories"
    case novaScotia = "Nova Scotia"
    case nunavut = "Nunavut"
    case ontario = "Ontario"
    case princeEdwardIsland = "Prince Edward Island"
    case quebec = "Quebec"
    case saskatchewan = "Saskatchewan"
    case yukon = "Yukon"

    var id: String { rawValue }
}

enum FinancialGoal: String, CaseIterable, Codable, Identifiable {
    case reduceUnnecessarySpending = "Reduce unnecessary spending"
    case buildEmergencyFund = "Build emergency fund"
    case payDebt = "Pay debt"
    case saveForHome = "Save for home"
    case saveForCar = "Save for car"
    case controlMonthlySpending = "Control monthly spending"

    var id: String { rawValue }
}

enum PayFrequency: String, CaseIterable, Codable, Identifiable {
    case biweekly = "Biweekly"
    case weekly = "Weekly"
    case semiMonthly = "Semi-Monthly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

enum CategoryType: String, CaseIterable, Codable, Identifiable {
    case need
    case want
    case saving
    case debt

    var id: String { rawValue }
}

enum TransactionSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case receiptOCR
    case recurringBill
    case adjustment

    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case debit = "Debit"
    case credit = "Credit Card"
    case cash = "Cash"
    case eTransfer = "E-Transfer"
    case other = "Other"

    var id: String { rawValue }
}

enum RecurringFrequency: String, CaseIterable, Codable, Identifiable {
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

enum ReceiptType: String, CaseIterable, Codable, Identifiable {
    case retail
    case grocery
    case restaurant
    case fuel
    case bill
    case other

    var id: String { rawValue }
}

enum BenchmarkConfidence: String, CaseIterable, Codable, Identifiable {
    case rough
    case moderate
    case strong

    var id: String { rawValue }
}

enum BenchmarkComparisonStatus: String, CaseIterable, Codable, Identifiable {
    case higherThanBenchmark = "higher than benchmark"
    case withinRange = "within range"
    case lowerThanBenchmark = "lower than benchmark"

    var id: String { rawValue }
}

enum BudgetCategoryName: String, CaseIterable, Codable, Identifiable {
    case housing = "Housing"
    case groceries = "Groceries"
    case restaurantsCoffee = "Restaurants / Coffee"
    case transportation = "Transportation"
    case gas = "Gas"
    case utilities = "Utilities"
    case phoneInternet = "Phone / Internet"
    case kids = "Kids"
    case healthPharmacy = "Health / Pharmacy"
    case subscriptions = "Subscriptions"
    case clothing = "Clothing"
    case homeHousehold = "Home / Household"
    case entertainment = "Entertainment"
    case personalCare = "Personal Care"
    case education = "Education"
    case gifts = "Gifts"
    case travel = "Travel"
    case debtRepayment = "Debt Repayment"
    case savings = "Savings"
    case miscellaneous = "Miscellaneous"

    var id: String { rawValue }

    var defaultType: CategoryType {
        switch self {
        case .housing, .groceries, .transportation, .gas, .utilities, .phoneInternet, .kids, .healthPharmacy:
            return .need
        case .savings:
            return .saving
        case .debtRepayment:
            return .debt
        default:
            return .want
        }
    }
}

struct ReceiptFieldConfidence: Codable, Hashable {
    var merchant: Double
    var date: Double
    var subtotal: Double
    var tax: Double
    var tip: Double
    var discount: Double
    var total: Double

    static let zero = ReceiptFieldConfidence(
        merchant: 0,
        date: 0,
        subtotal: 0,
        tax: 0,
        tip: 0,
        discount: 0,
        total: 0
    )
}

@Model
final class UserProfile {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var familySize: Int
    var numberOfAdults: Int
    var numberOfChildren: Int
    var provinceRawValue: String
    var city: String?
    var currencyCode: String
    var biweeklyNetSalary: Double
    var firstKnownPayday: Date
    var rentOrMortgageAmount: Double
    var otherFixedMonthlyExpenses: Double
    var monthlySavingsTarget: Double
    var mainGoalRawValue: String
    var payFrequencyRawValue: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        familySize: Int,
        numberOfAdults: Int,
        numberOfChildren: Int,
        province: Province,
        city: String? = nil,
        currencyCode: String = "CAD",
        biweeklyNetSalary: Double,
        firstKnownPayday: Date,
        rentOrMortgageAmount: Double,
        otherFixedMonthlyExpenses: Double,
        monthlySavingsTarget: Double,
        mainGoal: FinancialGoal,
        payFrequency: PayFrequency = .biweekly
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.familySize = familySize
        self.numberOfAdults = numberOfAdults
        self.numberOfChildren = numberOfChildren
        self.provinceRawValue = province.rawValue
        self.city = city
        self.currencyCode = currencyCode
        self.biweeklyNetSalary = biweeklyNetSalary
        self.firstKnownPayday = firstKnownPayday
        self.rentOrMortgageAmount = rentOrMortgageAmount
        self.otherFixedMonthlyExpenses = otherFixedMonthlyExpenses
        self.monthlySavingsTarget = monthlySavingsTarget
        self.mainGoalRawValue = mainGoal.rawValue
        self.payFrequencyRawValue = payFrequency.rawValue
    }

    var province: Province {
        get { Province(rawValue: provinceRawValue) ?? .ontario }
        set { provinceRawValue = newValue.rawValue }
    }

    var mainGoal: FinancialGoal {
        get { FinancialGoal(rawValue: mainGoalRawValue) ?? .controlMonthlySpending }
        set { mainGoalRawValue = newValue.rawValue }
    }

    var payFrequency: PayFrequency {
        get { PayFrequency(rawValue: payFrequencyRawValue) ?? .biweekly }
        set { payFrequencyRawValue = newValue.rawValue }
    }
}

@Model
final class BudgetMonth {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var monthStart: Date
    var plannedIncome: Double
    var actualIncome: Double
    var fixedExpenses: Double
    var variableSpending: Double
    var savingsTarget: Double

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        monthStart: Date,
        plannedIncome: Double = 0,
        actualIncome: Double = 0,
        fixedExpenses: Double = 0,
        variableSpending: Double = 0,
        savingsTarget: Double = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.monthStart = monthStart
        self.plannedIncome = plannedIncome
        self.actualIncome = actualIncome
        self.fixedExpenses = fixedExpenses
        self.variableSpending = variableSpending
        self.savingsTarget = savingsTarget
    }
}

@Model
final class BudgetCategory {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var nameRawValue: String
    var categoryTypeRawValue: String
    var monthlyLimit: Double
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        name: BudgetCategoryName,
        categoryType: CategoryType,
        monthlyLimit: Double = 0,
        sortOrder: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.nameRawValue = name.rawValue
        self.categoryTypeRawValue = categoryType.rawValue
        self.monthlyLimit = monthlyLimit
        self.sortOrder = sortOrder
    }

    var name: BudgetCategoryName {
        get { BudgetCategoryName(rawValue: nameRawValue) ?? .miscellaneous }
        set { nameRawValue = newValue.rawValue }
    }

    var categoryType: CategoryType {
        get { CategoryType(rawValue: categoryTypeRawValue) ?? .want }
        set { categoryTypeRawValue = newValue.rawValue }
    }
}

@Model
final class Receipt {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var imageData: Data?
    var localImageReference: String?
    var rawOCRText: String
    var merchantName: String?
    var transactionDate: Date?
    var subtotal: Double?
    var tax: Double?
    var tip: Double?
    var discount: Double?
    var total: Double?
    var confidenceScore: Double
    var receiptTypeRawValue: String
    @Relationship(deleteRule: .cascade) var lineItems: [ReceiptLineItem]
    var userReviewed: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        imageData: Data? = nil,
        localImageReference: String? = nil,
        rawOCRText: String = "",
        merchantName: String? = nil,
        transactionDate: Date? = nil,
        subtotal: Double? = nil,
        tax: Double? = nil,
        tip: Double? = nil,
        discount: Double? = nil,
        total: Double? = nil,
        confidenceScore: Double = 0,
        receiptType: ReceiptType = .other,
        lineItems: [ReceiptLineItem] = [],
        userReviewed: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageData = imageData
        self.localImageReference = localImageReference
        self.rawOCRText = rawOCRText
        self.merchantName = merchantName
        self.transactionDate = transactionDate
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.discount = discount
        self.total = total
        self.confidenceScore = confidenceScore
        self.receiptTypeRawValue = receiptType.rawValue
        self.lineItems = lineItems
        self.userReviewed = userReviewed
    }

    var receiptType: ReceiptType {
        get { ReceiptType(rawValue: receiptTypeRawValue) ?? .other }
        set { receiptTypeRawValue = newValue.rawValue }
    }
}

@Model
final class ReceiptLineItem {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var itemName: String
    var quantity: Double?
    var unitPrice: Double?
    var totalPrice: Double
    var detectedCategoryRawValue: String?
    var confidenceScore: Double
    var userCorrected: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        itemName: String,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        totalPrice: Double,
        detectedCategoryRawValue: String? = nil,
        confidenceScore: Double = 0,
        userCorrected: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemName = itemName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.detectedCategoryRawValue = detectedCategoryRawValue
        self.confidenceScore = confidenceScore
        self.userCorrected = userCorrected
    }

    var detectedCategory: BudgetCategoryName? {
        get {
            guard let detectedCategoryRawValue else { return nil }
            return BudgetCategoryName(rawValue: detectedCategoryRawValue)
        }
        set {
            detectedCategoryRawValue = newValue?.rawValue
        }
    }
}

@Model
final class Transaction {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var amount: Double
    var date: Date
    var merchant: String
    var note: String
    var categoryRawValue: String
    var categoryTypeRawValue: String
    var paymentMethodRawValue: String
    var sourceRawValue: String
    var isUnnecessary: Bool
    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        amount: Double,
        date: Date,
        merchant: String,
        note: String = "",
        category: BudgetCategoryName,
        categoryType: CategoryType,
        paymentMethod: PaymentMethod,
        source: TransactionSource = .manual,
        isUnnecessary: Bool = false,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.note = note
        self.categoryRawValue = category.rawValue
        self.categoryTypeRawValue = categoryType.rawValue
        self.paymentMethodRawValue = paymentMethod.rawValue
        self.sourceRawValue = source.rawValue
        self.isUnnecessary = isUnnecessary
        self.receipt = receipt
    }

    var category: BudgetCategoryName {
        get { BudgetCategoryName(rawValue: categoryRawValue) ?? .miscellaneous }
        set { categoryRawValue = newValue.rawValue }
    }

    var categoryType: CategoryType {
        get { CategoryType(rawValue: categoryTypeRawValue) ?? .want }
        set { categoryTypeRawValue = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRawValue) ?? .other }
        set { paymentMethodRawValue = newValue.rawValue }
    }

    var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }
}

@Model
final class RecurringBill {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var amount: Double
    var categoryRawValue: String
    var frequencyRawValue: String
    var dueDay: Int
    var startDate: Date
    var endDate: Date?
    var active: Bool
    var reminderEnabled: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        name: String,
        amount: Double,
        category: BudgetCategoryName,
        frequency: RecurringFrequency = .monthly,
        dueDay: Int,
        startDate: Date,
        endDate: Date? = nil,
        active: Bool = true,
        reminderEnabled: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.amount = amount
        self.categoryRawValue = category.rawValue
        self.frequencyRawValue = frequency.rawValue
        self.dueDay = dueDay
        self.startDate = startDate
        self.endDate = endDate
        self.active = active
        self.reminderEnabled = reminderEnabled
    }

    var category: BudgetCategoryName {
        get { BudgetCategoryName(rawValue: categoryRawValue) ?? .miscellaneous }
        set { categoryRawValue = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }
}

@Model
final class MerchantRule {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var merchantName: String
    var mappedCategoryRawValue: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        merchantName: String,
        mappedCategory: BudgetCategoryName
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.merchantName = merchantName
        self.mappedCategoryRawValue = mappedCategory.rawValue
    }

    var mappedCategory: BudgetCategoryName {
        get { BudgetCategoryName(rawValue: mappedCategoryRawValue) ?? .miscellaneous }
        set { mappedCategoryRawValue = newValue.rawValue }
    }
}

@Model
final class CategoryRule {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var keyword: String
    var mappedCategoryRawValue: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        keyword: String,
        mappedCategory: BudgetCategoryName
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.keyword = keyword
        self.mappedCategoryRawValue = mappedCategory.rawValue
    }

    var mappedCategory: BudgetCategoryName {
        get { BudgetCategoryName(rawValue: mappedCategoryRawValue) ?? .miscellaneous }
        set { mappedCategoryRawValue = newValue.rawValue }
    }
}

@Model
final class MonthlyInsight {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var monthStart: Date
    var title: String
    var detail: String
    var severity: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        monthStart: Date,
        title: String,
        detail: String,
        severity: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.monthStart = monthStart
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

@Model
final class BenchmarkRecord {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var year: Int
    var geography: String
    var averageHouseholdSpending: Double
    var shelterShare: Double
    var transportationShare: Double
    var foodShare: Double
    var confidenceRawValue: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        year: Int,
        geography: String,
        averageHouseholdSpending: Double,
        shelterShare: Double,
        transportationShare: Double,
        foodShare: Double,
        confidence: BenchmarkConfidence
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.year = year
        self.geography = geography
        self.averageHouseholdSpending = averageHouseholdSpending
        self.shelterShare = shelterShare
        self.transportationShare = transportationShare
        self.foodShare = foodShare
        self.confidenceRawValue = confidence.rawValue
    }

    var confidence: BenchmarkConfidence {
        get { BenchmarkConfidence(rawValue: confidenceRawValue) ?? .rough }
        set { confidenceRawValue = newValue.rawValue }
    }
}

@Model
final class AppSettings {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var useLargeNumbersOnDashboard: Bool
    var showRawOCRDebug: Bool
    var exportCSVEnabled: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        useLargeNumbersOnDashboard: Bool = true,
        showRawOCRDebug: Bool = false,
        exportCSVEnabled: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.useLargeNumbersOnDashboard = useLargeNumbersOnDashboard
        self.showRawOCRDebug = showRawOCRDebug
        self.exportCSVEnabled = exportCSVEnabled
    }
}
