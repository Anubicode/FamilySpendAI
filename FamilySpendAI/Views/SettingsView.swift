import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @State private var showingDeleteAlert = false
    @State private var resetError: String?

    var body: some View {
        List {
            Section("Local-first") {
                LabeledContent("Storage", value: "On device with SwiftData")
                LabeledContent("Cloud AI", value: "Disabled in MVP")
                LabeledContent("Currency", value: "CAD")
            }

            if let appSettings = settings.first {
                Section("Preferences") {
                    Toggle("Show compact dashboard highlights", isOn: Binding(
                        get: { appSettings.useLargeNumbersOnDashboard },
                        set: { newValue in
                            appSettings.useLargeNumbersOnDashboard = newValue
                            appSettings.updatedAt = .now
                            try? modelContext.save()
                        }
                    ))
                    .accessibilityLabel("Toggle dashboard highlights")
                }
            }

            Section("Privacy") {
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label("Privacy details", systemImage: "hand.raised.fill")
                }
                .accessibilityLabel("Open privacy details")
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
                .accessibilityLabel("Delete all local data")
            }

            if let resetError {
                Section {
                    Text(resetError)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Delete all data?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                do {
                    try DataResetService.deleteAllData(in: modelContext)
                    try SampleDataService.ensureGlobalDefaults(in: modelContext)
                    resetError = nil
                } catch {
                    resetError = "Unable to clear local data. \(error.localizedDescription)"
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes onboarding data, budgets, bills, transactions, and local settings from this device.")
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("What is stored") {
                Text("Your profile, budgets, bills, transactions, and app settings are stored locally on this device.")
                Text("Receipt images and OCR outputs are not part of Phase 1 and no cloud processing is active.")
            }

            Section("Where it is stored") {
                Text("FamilySpend AI uses SwiftData local storage. There are no fake bank connections and no live external sync in this MVP.")
            }

            Section("AI status") {
                Text("Cloud AI is disabled in the MVP. A future AI service will be added behind a protocol so you can choose whether to enable it later.")
            }

            Section("Your control") {
                Text("You can delete all local app data at any time from Settings.")
            }
        }
        .navigationTitle("Privacy")
    }
}
