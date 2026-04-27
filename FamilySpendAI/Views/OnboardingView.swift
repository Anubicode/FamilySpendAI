import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        Form {
            Section("Household") {
                Stepper("Family size: \(viewModel.draft.familySize)", value: $viewModel.draft.familySize, in: 1...12)
                    .accessibilityLabel("Family size")
                Stepper("Adults: \(viewModel.draft.numberOfAdults)", value: $viewModel.draft.numberOfAdults, in: 1...8)
                    .accessibilityLabel("Number of adults")
                Stepper("Children: \(viewModel.draft.numberOfChildren)", value: $viewModel.draft.numberOfChildren, in: 0...10)
                    .accessibilityLabel("Number of children")
                Picker("Province", selection: $viewModel.draft.province) {
                    ForEach(Province.allCases) { province in
                        Text(province.rawValue).tag(province)
                    }
                }
                TextField("City (optional)", text: $viewModel.draft.city)
                    .textInputAutocapitalization(.words)
            }

            Section("Income") {
                LabeledContent("Currency", value: "CAD")
                TextField("Biweekly net salary", value: $viewModel.draft.biweeklyNetSalary, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Biweekly net salary")
                DatePicker("First known payday", selection: $viewModel.draft.firstKnownPayday, displayedComponents: .date)
                    .accessibilityLabel("First known payday date")
            }

            Section("Monthly commitments") {
                TextField("Rent or mortgage", value: $viewModel.draft.rentOrMortgageAmount, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Rent or mortgage amount")
                TextField("Other fixed monthly expenses", value: $viewModel.draft.otherFixedMonthlyExpenses, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Other fixed monthly expenses")
                TextField("Monthly savings target", value: $viewModel.draft.monthlySavingsTarget, format: .currency(code: "CAD"))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Monthly savings target")
            }

            Section("Goal") {
                Picker("Main goal", selection: $viewModel.draft.mainGoal) {
                    ForEach(FinancialGoal.allCases) { goal in
                        Text(goal.rawValue).tag(goal)
                    }
                }
                .accessibilityLabel("Main goal")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    viewModel.save(in: modelContext)
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Finish Setup")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
                .accessibilityLabel("Finish onboarding")
            }
        }
        .navigationTitle("FamilySpend AI")
    }
}
