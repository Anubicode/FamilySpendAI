# FamilySpend AI - Phase 1 Implementation Plan

## Scope

Implement Phase 1 only:

- SwiftData models
- Local seed/default data
- Onboarding
- Manual transactions
- Category budgets
- Recurring bills basic model
- Deterministic `BudgetEngine`
- Dashboard
- Settings and privacy controls
- Unit tests for budget logic

Out of scope for Phase 1:

- OCR camera and receipt parsing flows
- Real AI providers
- Receipt review workflow
- Benchmark UI
- Insight engine UI
- Charts implementation

## Architecture

- Platform: iOS 17+
- UI: SwiftUI with `TabView` + `NavigationStack`
- Persistence: SwiftData
- Pattern: MVVM
- Budget logic: pure functions inside `BudgetEngine`
- AI seam: protocol-first design, mock-only in later phases
- Storage: local-first on-device only

## Models

Phase 1 will include these SwiftData models so the schema is future-ready:

- `UserProfile`
- `BudgetMonth`
- `BudgetCategory`
- `Transaction`
- `Receipt`
- `ReceiptLineItem`
- `RecurringBill`
- `MerchantRule`
- `CategoryRule`
- `MonthlyInsight`
- `BenchmarkRecord`
- `AppSettings`

## Services

- `BudgetEngine`
  - payday generation
  - monthly income calculation
  - 2-paycheck / 3-paycheck month detection
  - fixed-expense deduction
  - discretionary budget and safe-to-spend
  - category budget remaining / over-budget logic
- `SampleDataService`
  - seed default app settings
  - seed default category budgets and category type mappings
- `DataResetService`
  - delete all local data

## Screens

Phase 1 screens:

- `OnboardingView`
- `DashboardView`
- `TransactionsView`
- `AddTransactionView`
- `BudgetsView`
- `CategoryDetailView`
- `BillsView`
- `SettingsView`
- `PrivacyView`

Phase 2 placeholder tabs, clearly marked:

- `Scan`
- `Charts`
- `Insights`

## Test Cases

Phase 1 test coverage:

- payday generation from first known payday
- monthly income calculation for a 2-paycheck month
- monthly income calculation for a 3-paycheck month
- fixed expense deduction
- safe-to-spend calculation
- category budget remaining calculation
- over-budget detection
- next payday calculation

Deferred to Phase 2+:

- receipt total parsing
- receipt tax parsing
- categorization keyword rules
- merchant override rules
- benchmark comparison rules

## Delivery Notes

- No hardcoded API keys
- No real bank integrations
- No regulated financial advice language
- All OCR and AI work deferred from Phase 1
- Every major calculation lives in testable pure functions
