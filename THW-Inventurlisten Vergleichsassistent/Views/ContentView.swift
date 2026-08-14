//
//  ContentView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import SwiftUI
import UniformTypeIdentifiers


/// A SwiftUI view that drives the UI for comparing two XLSX inventory lists.
///
/// ContentView presents two file selection actions (“Alte Datei wählen” and “Neue Datei wählen”)
/// to import .xlsx files using the system file importer. Once both files are loaded, it delegates
/// to `DiffView` to visualize the computed differences provided by `XLSXViewModel`.
///
/// Responsibilities:
/// - Manages UI state for selecting and loading two documents (“old” and “new”) via `.fileImporter`.
/// - Coordinates with `XLSXViewModel` to store loaded documents, compute diffs, and surface errors.
/// - Presents a confirmation alert if the user attempts to replace an already loaded document.
/// - Provides a toolbar action to reset the current state (clears loaded documents and diff).
///
/// Key properties:
/// - `viewModel`: The `XLSXViewModel` instance holding loaded documents, errors, and the diff.
/// - `activeSlot`: The document slot currently targeted by the file importer (old/new).
/// - `lastRequestedSlot`: Remembers which slot the user last requested, used to resolve importer callbacks.
/// - `showOverwriteConfirmation`: Controls presentation of the overwrite confirmation alert.
/// - `pendingSlot`: Temporarily stores the slot that the user intends to overwrite, confirmed via alert.
///
/// User flow:
/// 1. The user taps “Alte Datei wählen” or “Neue Datei wählen”.
/// 2. If a file is already loaded for that slot, a confirmation alert is shown before proceeding.
/// 3. On confirmation (or if the slot was empty), the system file importer is presented for `.xlsx`.
/// 4. On successful selection, the file’s data is read with security-scoped access and passed to the view model.
/// 5. Errors are displayed inline; when both files are loaded and a diff exists, `DiffView` is shown.
///
/// Platform considerations:
/// - Uses `UniformTypeIdentifiers` to restrict the importer to `.xlsx`.
/// - Uses security-scoped resource access to read files from sandboxed locations.
/// - Designed for Apple platform SwiftUI apps with a `NavigationStack` and toolbar.
///
/// Note:
/// - This view assumes the presence of `XLSXViewModel`, its `DocumentSlot` type, and `DiffView`.
/// - Prefer keeping file I/O on background queues if large files are expected; consider adapting
///   `loadFile` to use Swift concurrency for smoother UI responsiveness.
struct ContentView: View {
    @State private var viewModel = XLSXViewModel()
    @State private var activeSlot: XLSXViewModel.DocumentSlot?
    @State private var lastRequestedSlot: XLSXViewModel.DocumentSlot?
 
    // Bestätigungs-Popup beim Überschreiben eines bereits geladenen Slots
    @State private var showResetConfirmation = false
    @State private var showOverwriteConfirmation = false
    @State private var pendingSlot: XLSXViewModel.DocumentSlot?
 
    private var isImporterPresented: Binding<Bool> {
        Binding(
            get: { activeSlot != nil },
            set: { isPresented in
                if !isPresented { activeSlot = nil }
            }
        )
    }
 
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Button("") {
                            requestFile(for: .old)
                        }
                        .buttonStyle(
                            .fileImporter(
                                title: "Alte Inventur wählen",
                                subtitle: ".xlsx",
                                systemImage: "arrow.up.doc.fill",
                                isSelected: viewModel.oldDocument != nil
                            )
                        )
                    }
                    Spacer()
                    
                    VStack {
                        Button("") {
                            requestFile(for: .new)
                        }
                        .buttonStyle(
                            .fileImporter(
                                title: "Neue Inventur wählen",
                                subtitle: ".xlsx",
                                systemImage: "arrow.up.doc.fill",
                                isSelected: viewModel.newDocument != nil
                            )
                        )
                        
                    }
                    Spacer()
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                
                Spacer()
                Text("Bitte beide Dateien auswählen")
                    .foregroundStyle(.primary)
                    .font(.title)
                    .bold()
                Spacer()
            }
            .padding()
            .navigationTitle("THW-Inventur Vergleichs Assistent")
            .navigationDestination(isPresented: Binding(
                get: { viewModel.diff != nil },
                set: { if !$0 { viewModel.reset() } }
            )) {
                if let diff = viewModel.diff {
                    DiffView(
                        diff: diff,
                        oldItems: viewModel.oldDocument?.inventurliste ?? [],
                        newItems: viewModel.newDocument?.inventurliste ?? [],
                        viewModel: viewModel
                    )
                    .navigationTitle("Vergleichsergebnis")
                }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: isImporterPresented, allowedContentTypes: [.xlsx]) { result in
            guard let slot = activeSlot ?? lastRequestedSlot else { return }
            handle(result, as: slot)
        }
        .alert("Datei bereits geladen", isPresented: $showOverwriteConfirmation) {
            Button("Abbrechen", role: .cancel) {
                pendingSlot = nil
            }
            Button("Überschreiben", role: .destructive) {
                if let slot = pendingSlot {
                    lastRequestedSlot = slot
                    activeSlot = slot
                }
                pendingSlot = nil
            }
        } message: {
            Text("Für diesen Slot ist bereits eine Datei geladen. Möchtest du sie durch eine neue ersetzen?")
        }
    }
 
    /// Prüft, ob für den Slot schon eine Datei existiert, und fragt ggf. vorher per Popup nach
    private func requestFile(for slot: XLSXViewModel.DocumentSlot) {
        let alreadyLoaded: Bool = {
            switch slot {
            case .old: return viewModel.oldDocument != nil
            case .new: return viewModel.newDocument != nil
            }
        }()
 
        if alreadyLoaded {
            pendingSlot = slot
            showOverwriteConfirmation = true
        } else {
            lastRequestedSlot = slot
            activeSlot = slot
        }
    }
 
    private func handle(_ result: Result<URL, Error>, as slot: XLSXViewModel.DocumentSlot) {
        switch result {
        case .success(let url):
            loadFile(at: url, as: slot)
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
 
    private func loadFile(at url: URL, as slot: XLSXViewModel.DocumentSlot) {
        guard url.startAccessingSecurityScopedResource() else {
            viewModel.errorMessage = "Kein Zugriff auf die Datei"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
 
        do {
            let data = try Data(contentsOf: url)
            viewModel.load(data: data, as: slot)
        } catch {
            viewModel.errorMessage = "Fehler beim Lesen: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
