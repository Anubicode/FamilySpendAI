import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    BillsView()
                } label: {
                    Label("Recurring Bills", systemImage: "arrow.clockwise.circle")
                }
                .accessibilityLabel("Open recurring bills")
            }

            Section("Category Budgets") {
                ForEach(categories) { category in
                    let spent = currentMonthSpend(for: category.name)
                    let status = BudgetEngine.categoryBudgetStatus(
                        category: category.name,
                        budgeted: Decimal(category.monthlyLimit),
                        spent: spent
                    )

                    NavigationLink {
                        CategoryDetailView(category: category, spent: spent)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(category.name.rawValue)
                                Spacer()
                                Text(Formatters.currency(category.monthlyLimit))
                                    .fontWeight(.semibold)
                            }
                            HStack {
                                Text("Spent \(Formatters.currency(spent))")
                                Spacer()
                                Text(status.isOverBudget ? "Over by \(Formatters.currency(status.overBudgetAmount))" : "Remaining \(Formatters.currency(status.remaining))")
                                    .foregroundStyle(status.isOverBudget ? .red : .secondary)
                            }
                            .font(.caption)
                        }
                    }
                    .accessibilityLabel("\(category.name.rawValue), budget \(Formatters.currency(category.monthlyLimit))")
                }
            }
        }
        .navigationTitle("Budgets")
    }

    private func currentMonthSpend(for category: BudgetCategoryName) -> Decimal {
        transactions
            .filter {
                $0.category == category &&
                Calendar.canadian.isDate($0.date, equalTo: .now, toGranularity: .month)
            }
            .reduce(Decimal.zero) { $0 + Decimal($1.amount) }
    }
}

struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: BudgetCategory
    let spent: Decimal

    @State private var monthlyLimit: Double
    @State private var categoryType: CategoryType

    init(category: BudgetCategory, spent: Decimal) {
        self.category = category
        self.spent = spent
        _monthlyLimit = State(initialValue: category.monthlyLimit)
        _categoryType = State(initialValue: category.categoryType)
    }

    var body: some View {
        Form {
            Section("Budget") {
                LabeledContent("Category", value: category.name.rawValue)
                TextField("Monthly limit", value: $monthlyLimit, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Monthly budget limit")
                Picker("Classification", selection: $categoryType) {
                    ForEach(CategoryType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .accessibilityLabel("Category classification")
            }

            Section("This month") {
                LabeledContent("Spent", value: Formatters.currency(spent))
                LabeledContent("Remaining", value: Formatters.currency(Decimal(monthlyLimit) - spent))
            }
        }
        .navigationTitle(category.name.rawValue)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    category.monthlyLimit = monthlyLimit
                    category.categoryType = categoryType
                    category.updatedAt = .now
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringBill.dueDay) private var bills: [RecurringBill]
    @State private var showingAddBill = false

    var body: some View {
        List {
            if bills.isEmpty {
                ContentUnavailableView(
                    "No recurring bills",
                    systemImage: "calendar.badge.plus",
                    description: Text("Add your predictable bills so the dashboard reserves space for them.")
                )
            } else {
                ForEach(bills) { bill in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(bill.name)
                                .font(.headline)
                            Spacer()
                            Text(Formatters.currency(bill.amount))
                                .fontWeight(.semibold)
                        }
                        Text("\(bill.category.rawValue) - due day \(bill.dueDay)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Toggle("Active", isOn: Binding(
                            get: { bill.active },
                            set: { newValue in
                                bill.active = newValue
                                bill.updatedAt = .now
                                try? modelContext.save()
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteBills)
            }
        }
        .navigationTitle("Recurring Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddBill = true
                } label: {
                    Label("Add bill", systemImage: "plus")
                }
                .accessibilityLabel("Add recurring bill")
            }
        }
        .sheet(isPresented: $showingAddBill) {
            NavigationStack {
                AddRecurringBillView()
            }
        }
    }

    private func deleteBills(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bills[index])
        }
        try? modelContext.save()
    }
}

private struct AddRecurringBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = BillEditorViewModel()

    var body: some View {
        Form {
            Section("Bill") {
                TextField("Name", text: $viewModel.draft.name)
                    .accessibilityLabel("Bill name")
                TextField("Amount", value: $viewModel.draft.amount, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Bill amount")
                Picker("Category", selection: $viewModel.draft.category) {
                    ForEach(BudgetCategoryName.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                Picker("Frequency", selection: $viewModel.draft.frequency) {
                    ForEach(RecurringFrequency.allCases) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                Stepper("Due day: \(viewModel.draft.dueDay)", value: $viewModel.draft.dueDay, in: 1...28)
                    .accessibilityLabel("Due day")
                Toggle("Enable reminder", isOn: $viewModel.draft.reminderEnabled)
                    .accessibilityLabel("Enable reminder")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Bill")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.save(in: modelContext) {
                        dismiss()
                    }
                }
            }
        }
    }
}
