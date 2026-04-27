import PhotosUI
import SwiftUI

struct ScanReceiptView: View {
    private let launchOptions = AppLaunchOptions.current
    @StateObject private var viewModel = ReceiptScannerViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introCard
                sourceCard
                if launchOptions.isUITesting && launchOptions.shouldSeedSampleReceipts {
                    sampleReceiptsCard
                }
                statusCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scan Receipt")
        .sheet(item: $viewModel.reviewDraft) { draft in
            NavigationStack {
                ReceiptReviewView(
                    initialDraft: draft,
                    imageData: viewModel.selectedImageData
                ) {
                    selectedPhotoItem = nil
                    viewModel.clearResult()
                }
            }
        }
        .task(id: selectedPhotoItem) {
            if let selectedPhotoItem {
                await loadSelectedPhoto(from: selectedPhotoItem)
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Local receipt OCR", systemImage: "doc.text.viewfinder")
                .font(.headline)
            Text("Import a receipt photo and FamilySpend AI will run Apple Vision OCR on-device, parse the totals with deterministic rules, and always stop for your review before anything is saved.")
                .foregroundStyle(.secondary)
            Text("Camera capture can plug into this same review flow later. Phase 2 keeps the import path stable for CI and manual testing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Select receipt photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
            .accessibilityIdentifier("scan.importPhotoButton")

            Label("Photo Library access is handled by the system picker.", systemImage: "hand.raised")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
            } label: {
                Label("Camera capture coming next", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var sampleReceiptsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("UI test sample receipts", systemImage: "testtube.2")
                .font(.headline)
            Text("These synthetic receipts are generated in-app for UI testing only and run through the same OCR and parsing flow as a real imported image.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(SyntheticReceiptService.uiTestingSamples) { sample in
                Button {
                    Task {
                        await loadSampleReceipt(sample.kind)
                    }
                } label: {
                    Text(sample.displayName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
                .accessibilityIdentifier(sample.buttonIdentifier)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.isProcessing {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Running local OCR and receipt parsing...")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            if !viewModel.recognizedTextPreview.isEmpty {
                Text("OCR Preview")
                    .font(.headline)
                Text(viewModel.recognizedTextPreview)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }

            if viewModel.reviewDraft != nil && !viewModel.isProcessing {
                Text("The receipt review screen opens automatically when OCR is ready, and every OCR-generated transaction still needs confirmation before it can be saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    }

    @MainActor
    private func loadSelectedPhoto(from item: PhotosPickerItem) async {
        do {
            let data = try await item.loadTransferable(type: Data.self)
            await viewModel.processSelectedImageData(data)
        } catch {
            viewModel.clearResult()
            viewModel.errorMessage = "The selected image could not be loaded."
        }
    }

    @MainActor
    private func loadSampleReceipt(_ kind: SyntheticReceiptKind) async {
        selectedPhotoItem = nil

        guard let data = SyntheticReceiptService.imageData(for: kind) else {
            viewModel.clearResult()
            viewModel.errorMessage = "The synthetic sample receipt could not be generated."
            return
        }

        await viewModel.processSelectedImageData(data)
    }
}
