import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @State private var showingAddTransaction = false

    var body: some View {
        List {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No transactions yet",
                    systemImage: "tray",
                    description: Text("Add a manual transaction to start tracking family spending.")
                )
            } else {
                ForEach(transactions) { transaction in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(transaction.merchant)
                                .font(.headline)
                            Spacer()
                            Text(Formatters.currency(transaction.amount))
                                .fontWeight(.semibold)
                        }
                        Text(transaction.category.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(transaction.date.formatted(Formatters.shortDate))
                            Spacer()
                            Text(transaction.paymentMethod.rawValue)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                .onDelete(perform: deleteTransactions)
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Label("Add transaction", systemImage: "plus")
                }
                .accessibilityLabel("Add transaction")
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            NavigationStack {
                AddTransactionView(categories: categories)
            }
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(transactions[index])
        }
        try? modelContext.save()
    }
}

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let categories: [BudgetCategory]

    @StateObject private var viewModel = TransactionEditorViewModel()

    var body: some View {
        Form {
            Section("Expense") {
                TextField("Amount", value: $viewModel.draft.amount, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Transaction amount")
                DatePicker("Date", selection: $viewModel.draft.date, displayedComponents: .date)
                    .accessibilityLabel("Transaction date")
                TextField("Merchant or description", text: $viewModel.draft.merchant)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Merchant or description")
                Picker("Category", selection: $viewModel.draft.category) {
                    ForEach(categories, id: \.id) { category in
                        Text(category.name.rawValue).tag(category.name)
                    }
                }
                .accessibilityLabel("Transaction category")
                Picker("Payment method", selection: $viewModel.draft.paymentMethod) {
                    ForEach(PaymentMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .accessibilityLabel("Payment method")
                Toggle("Recurring bill", isOn: $viewModel.draft.isRecurring)
                    .accessibilityLabel("Mark as recurring bill")
                Toggle("Unnecessary spending", isOn: $viewModel.draft.isUnnecessary)
                    .accessibilityLabel("Mark as unnecessary spending")
                TextField("Notes", text: $viewModel.draft.note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .accessibilityLabel("Transaction notes")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Transaction")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.save(in: modelContext, categoryLookup: categories) {
                        dismiss()
                    }
                }
                .accessibilityLabel("Save transaction")
            }
        }
    }
}
