//
//  MacAIFoodPickerView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 07.02.26.
//
//  macOS Foto-Picker fuer KI-Erkennung (Fotomediathek, Finder, Drag & Drop)
//

#if os(macOS)
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// macOS-Ansicht zum Laden von Fotos fuer die KI-Erkennung
struct MacAIFoodPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let selectedMealType: MealType
    let onComplete: () -> Void

    @State private var imageData: Data?
    @State private var photosItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var isDropTargeted = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let data = imageData {
                AIFoodAnalysisView(
                    imageData: data,
                    selectedDate: selectedDate,
                    selectedMealType: selectedMealType,
                    onComplete: onComplete
                )
            } else {
                pickerContent
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 450, idealHeight: 550)
    }

    // MARK: - Picker-Ansicht

    private var pickerContent: some View {
        VStack(spacing: 0) {
            // Toolbar mit Abbrechen
            HStack {
                Button("cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()

            Spacer()

            VStack(spacing: 24) {
                // Drop-Zone
                dropZone

                // Buttons
                HStack(spacing: 16) {
                    PhotosPicker(selection: $photosItem, matching: .images) {
                        Label("ai_mac_photos_button", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("ai_mac_file_button", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()

            Spacer()
        }
        .onChange(of: photosItem) { _, newItem in
            guard let newItem else { return }
            Task {
                // Full-Resolution-Loader umgeht auf macOS die Thumbnail-Falle von
                // loadTransferable(type: Data.self) — siehe PhotosPickerItem+FullResolution.
                if let data = await newItem.loadFullResolutionData() {
                    imageData = data
                } else {
                    errorMessage = String(localized: "ai_error_image_load")
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let gotAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if gotAccess { url.stopAccessingSecurityScopedResource() }
                }
                if let data = try? Data(contentsOf: url) {
                    imageData = data
                } else {
                    errorMessage = String(localized: "ai_error_image_load")
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Drop-Zone

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("ai_mac_drop_hint")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("ai_mac_drop_formats")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data {
                    DispatchQueue.main.async {
                        imageData = data
                    }
                }
            }
            return true
        }
    }
}
#endif
