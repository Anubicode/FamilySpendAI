import SwiftUI
import SwiftData

@MainActor
@main
struct FamilySpendAIApp: App {
    var sharedModelContainer: ModelContainer = {
        let launchOptions = AppLaunchOptions.current
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

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: launchOptions.isUITesting
        )

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            try AppLaunchBootstrapService.prepareModelContainer(container, options: launchOptions)
            return container
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
