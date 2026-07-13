//
//  SwiftUIView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

struct DiffView: View {
    let diff: XLSXDiff

    var body: some View {
        List {
            if !diff.added.isEmpty {
                Section("Neu (\(diff.added.count))") {
                    ForEach(diff.added.sorted { $0.Sachnummer < $1.Sachnummer }) { objekt in
                        BestandsobjektRow(objekt: objekt)
                            .listRowBackground(Color.green.opacity(0.08))
                    }
                }
            }

            if !diff.removed.isEmpty {
                Section("Entfernt (\(diff.removed.count))") {
                    ForEach(diff.removed.sorted { $0.Sachnummer < $1.Sachnummer }) { objekt in
                        BestandsobjektRow(objekt: objekt)
                            .listRowBackground(Color.red.opacity(0.08))
                    }
                }
            }

            if !diff.modified.isEmpty {
                Section("Geändert (\(diff.modified.count))") {
                    ForEach(diff.modified.sorted { $0.new.Sachnummer < $1.new.Sachnummer }, id: \.new.id) { change in
                        ModifiedBestandsobjektRow(old: change.alt, new: change.new)
                            .listRowBackground(Color.orange.opacity(0.08))
                    }
                }
            }

            if !diff.unchanged.isEmpty {
                Section {
                    NavigationLink {
                        UnchangedListView(items: diff.unchanged)
                    } label: {
                        Label("Unveränderte Einträge anzeigen (\(diff.unchanged.count))", systemImage: "arrow.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !diff.hasChanges {
                Text("Keine Unterschiede gefunden")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
 
// MARK: - Preview
 
#Preview {
    ContentView()
}
