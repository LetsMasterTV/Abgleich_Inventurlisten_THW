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
    
    /// Parameter: to handle the FileImporter
    @State private var activeSlot: XLSXViewModel.DocumentSlot?
    @State private var lastRequestedSlot: XLSXViewModel.DocumentSlot?

    /// Parameter :to Handle Pop up Overwriting Warning
    @State private var showOverwriteConfirmation = false
    @State private var pendingSlot: XLSXViewModel.DocumentSlot?

    /// A computed binding that drives the presentation of the system file importer.
    ///
    /// This binding maps the optional `activeSlot` state to a boolean that `.fileImporter`
    /// can observe:
    /// - get: Returns `true` when a document slot is active (non-nil), which presents the importer.
    /// - set: When the importer is dismissed (`false`), it clears `activeSlot` to end presentation.
    ///         Setting it to `true` has no effect here; presentation is triggered by assigning
    ///         a non-nil slot to `activeSlot` elsewhere (e.g., in `requestFile(for:)`).
    ///
    /// Rationale:
    /// SwiftUI’s `.fileImporter` requires a `Binding<Bool>` to manage presentation. Internally,
    /// this view tracks which document slot (old/new) is being targeted via `activeSlot`.
    /// By bridging the optional slot to a boolean, the importer is shown only when a slot
    /// has been selected, and automatically dismissed/reset when the importer completes.
    ///
    /// Notes:
    /// - The dismissal path intentionally clears `activeSlot` to avoid stale state and to
    ///   ensure subsequent presentations work reliably.
    /// - If the user cancels the importer, SwiftUI sets the binding to `false`, which
    ///   also clears `activeSlot`.
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
            VStack(spacing: 16) {
                HStack {
                    Button("Alte Datei wählen") {
                        requestFile(for: .old)
                    }
                    Spacer()
                    if viewModel.oldDocument != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }

                HStack {
                    Button("Neue Datei wählen") {
                        requestFile(for: .new)
                    }
                    Spacer()
                    if viewModel.newDocument != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if let diff = viewModel.diff {
                    DiffView(diff: diff)
                } else {
                    Spacer()
                    Text("Bitte beide Dateien auswählen")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Inventurlisten Vergleich")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        viewModel.reset()
                    } label: {
                        Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.oldDocument == nil && viewModel.newDocument == nil)
                }
            }
        }
        // MARK: File Importer
        .fileImporter(isPresented: isImporterPresented, allowedContentTypes: [.xlsx]) { result in
            guard let slot = activeSlot ?? lastRequestedSlot else { return }
            handle(result, as: slot)
        }
        // MARK: POP-UP "Datei Überschreiben"
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

//---------------------------------------------------------------------------------------------------------------------
    
    /// Prüft, ob für den Slot schon eine Datei existiert, und fragt ggf. vorher nach
    ///
    ///
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
 
//---------------------------------------------------------------------------------------------------------------------
    
    private func handle(_ result: Result<URL, Error>, as slot: XLSXViewModel.DocumentSlot) {
        switch result {
        case .success(let url):
            print("✅ handle(): Erfolg, URL = \(url)")
            loadFile(at: url, as: slot)
        case .failure(let error):
            print("❌ handle(): fileImporter lieferte Fehler: \(error)")
            viewModel.errorMessage = error.localizedDescription
        }
    }
    
//---------------------------------------------------------------------------------------------------------------------
 
    private func loadFile(at url: URL, as slot: XLSXViewModel.DocumentSlot) {
        print("📂 loadFile() gestartet für: \(url.lastPathComponent)")
        guard url.startAccessingSecurityScopedResource() else {
            print("🚫 startAccessingSecurityScopedResource() lieferte FALSE – kein Zugriff!")
            viewModel.errorMessage = "Kein Zugriff auf die Datei"
            return
        }
        print("🔓 Security-Scoped-Zugriff erfolgreich gestartet")
        defer {
            url.stopAccessingSecurityScopedResource()
            print("🔒 Security-Scoped-Zugriff wieder freigegeben")
        }
 
        do {
            let data = try Data(contentsOf: url)
            print("📄 Data(contentsOf:) erfolgreich, \(data.count) Bytes gelesen")
            viewModel.load(data: data, as: slot)
        } catch {
            print("❌ Data(contentsOf:) fehlgeschlagen: \(error)")
            viewModel.errorMessage = "Fehler beim Lesen: \(error.localizedDescription)"
        }
    }
}

//---------------------------------------------------------------------------------------------------------------------


#Preview {
    ContentView()
}
