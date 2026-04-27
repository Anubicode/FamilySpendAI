import SwiftUI
import SwiftData

@main
struct FamilySpendAIApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            BudgetMonth.self,
            BudgetCategory.self,
            Transaction.self,
            Receipt.self,
            ReceiptLineItem.self,
            RecurringBill.self,
            MerchantRule.self,
            CategoryRule.self,
            MonthlyInsight.self,
            BenchmarkRecord.self,
            AppSettings.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
