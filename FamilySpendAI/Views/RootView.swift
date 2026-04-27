import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                AppTabView(profile: profile)
            } else {
                NavigationStack {
                    OnboardingView()
                }
            }
        }
        .task {
            try? SampleDataService.ensureGlobalDefaults(in: modelContext)
        }
    }
}

private struct AppTabView: View {
    let profile: UserProfile

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(profile: profile)
            }
            .tabItem {
                Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
            }

            NavigationStack {
                ScanReceiptView()
            }
            .tabItem {
                Label("Scan", systemImage: "camera.viewfinder")
            }

            NavigationStack {
                TransactionsView()
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                BudgetsView()
            }
            .tabItem {
                Label("Budgets", systemImage: "wallet.bifold")
            }

            NavigationStack {
                PlaceholderFeatureView(
                    title: "Charts",
                    description: "Phase 2 will add Swift Charts for category, trend, and spending pattern analysis.",
                    systemImage: "chart.xyaxis.line"
                )
            }
            .tabItem {
                Label("Charts", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                PlaceholderFeatureView(
                    title: "Insights",
                    description: "Phase 2 will add practical spending insights built on deterministic rules first and AI hooks later.",
                    systemImage: "lightbulb.max"
                )
            }
            .tabItem {
                Label("Insights", systemImage: "sparkles")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.teal)
    }
}
