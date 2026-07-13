//
//  ContentView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {
    @State private var viewModel = XLSXViewModel()
    @State private var activeSlot: XLSXViewModel.DocumentSlot?
    @State private var lastRequestedSlot: XLSXViewModel.DocumentSlot?

    // NEU: steuert die Bestätigungs-Popmeldung
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
            .navigationTitle("XLSX Vergleich")
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
        .fileImporter(isPresented: isImporterPresented, allowedContentTypes: [.xlsx]) { result in
            guard let slot = activeSlot ?? lastRequestedSlot else { return }
            handle(result, as: slot)
        }
        // NEU: Bestätigungs-Popup
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

    /// Prüft, ob für den Slot schon eine Datei existiert, und fragt ggf. vorher nach
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
            print("✅ handle(): Erfolg, URL = \(url)")
            loadFile(at: url, as: slot)
        case .failure(let error):
            print("❌ handle(): fileImporter lieferte Fehler: \(error)")
            viewModel.errorMessage = error.localizedDescription
        }
    }
 
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
#Preview {
    ContentView()
}
