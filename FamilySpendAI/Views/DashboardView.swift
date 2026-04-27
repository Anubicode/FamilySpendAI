import SwiftUI
import SwiftData

struct DashboardView: View {
    let profile: UserProfile

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \RecurringBill.dueDay) private var recurringBills: [RecurringBill]

    private let viewModel = DashboardViewModel()

    var body: some View {
        let summary = viewModel.summary(
            profile: profile,
            transactions: transactions,
            categories: categories,
            recurringBills: recurringBills
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard(summary: summary)
                incomeCard(summary: summary)
                budgetHealthCard(summary: summary)
                topCategoriesCard(summary: summary)
                alertsCard(summary: summary)
                upcomingBillsCard(summary: summary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
    }

    private func headerCard(summary: BudgetDashboardData) -> some View {
        DashboardCard(title: "This Month", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.month.start.formatted(Formatters.monthYear))
                    .font(.title2.weight(.semibold))
                Text("Monthly income is based on actual paydays that land inside this calendar month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if summary.isThreePaycheckMonth {
                    Label("This is a 3-paycheck month. Treat the extra pay as a planned opportunity, not extra drift money.", systemImage: "star.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.teal)
                }
            }
        }
    }

    private func incomeCard(summary: BudgetDashboardData) -> some View {
        DashboardCard(title: "Income Snapshot", systemImage: "dollarsign.circle") {
            VStack(spacing: 12) {
                StatRow(label: "Monthly income", value: Formatters.currency(summary.monthlyIncome))
                StatRow(label: "Paychecks this month", value: "\(summary.paydays.count)")
                StatRow(label: "Next payday", value: summary.nextPayday?.formatted(Formatters.shortDate) ?? "Not available")
                StatRow(label: "Days left in month", value: "\(summary.daysRemaining)")
            }
        }
    }

    private func budgetHealthCard(summary: BudgetDashboardData) -> some View {
        DashboardCard(title: "Budget Health", systemImage: "wallet.pass") {
            VStack(spacing: 12) {
                StatRow(label: "Total spent", value: Formatters.currency(summary.totalSpent))
                StatRow(label: "Remaining budget", value: Formatters.currency(summary.remainingBudget))
                StatRow(label: "Fixed expenses", value: Formatters.currency(summary.fixedExpenses))
                StatRow(label: "Variable spending", value: Formatters.currency(summary.variableSpending))
                StatRow(label: "Savings progress", value: "\(Formatters.currency(summary.savingsProgress)) / \(Formatters.currency(profile.monthlySavingsTarget))")
                StatRow(label: "Daily safe-to-spend", value: Formatters.currency(summary.safeToSpendPerDay))
                StatRow(label: "Unnecessary spending estimate", value: Formatters.currency(summary.unnecessarySpending))
            }
        }
    }

    private func topCategoriesCard(summary: BudgetDashboardData) -> some View {
        DashboardCard(title: "Top Categories", systemImage: "chart.bar") {
            if summary.topCategories.isEmpty {
                EmptyStateView(
                    title: "No spending yet",
                    subtitle: "Add transactions to see where this month is going."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(summary.topCategories.enumerated()), id: \.offset) { item in
                        StatRow(label: item.element.0.rawValue, value: Formatters.currency(item.element.1))
                    }
                }
            }
        }
    }

    private func alertsCard(summary: BudgetDashboardData) -> some View {
        DashboardCard(title: "Watchouts", systemImage: "exclamationmark.triangle") {
            let overspent = summary.categoryStatuses.filter(\.isOverBudget)
            if overspent.isEmpty && summary.remainingBudget >= 0 {
                EmptyStateView(
                    title: "You're on track",
                    subtitle: "No categories are currently over budget."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if summary.remainingBudget < 0 {
                        Label("You are over your discretionary budget by \(Formatters.currency(-summary.remainingBudget)).", systemImage: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    ForEach(overspent) { status in
                        Label("\(status.category.rawValue) is over budget by \(Formatters.currency(status.overBudgetAmount)).", systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func upcomingBillsCard(summary: BudgetDashboardData) -> some View {
        DashboardCard(title: "Upcoming Bills", systemImage: "calendar.badge.clock") {
            if summary.upcomingBills.isEmpty {
                EmptyStateView(
                    title: "No recurring bills yet",
                    subtitle: "Add one in Budgets to reserve space for fixed costs."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.upcomingBills) { bill in
                        StatRow(
                            label: "\(bill.name) - \(bill.dueDate.formatted(Formatters.shortDate))",
                            value: Formatters.currency(bill.amount)
                        )
                    }
                }
            }
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
