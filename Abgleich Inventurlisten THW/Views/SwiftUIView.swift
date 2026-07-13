//
//  SwiftUIView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

/// A SwiftUI view that presents a summarized, sectioned list of differences between two XLSX-based inventories.
///
/// DiffView renders the result of a comparison (diff) of inventory items into a user-friendly list:
/// - Added items are shown in a "Neu" section with a light green background.
/// - Removed items are shown in an "Entfernt" section with a light red background.
/// - Modified items are shown in a "Geändert" section with a light orange background, displaying both old and new values.
/// - Unchanged items are accessible via a navigation link to a dedicated list to keep the main view focused on changes.
/// - If no differences exist, a secondary-styled message is shown.
///
/// The list content is grouped into sections only when the corresponding category is non-empty. Items within sections
/// are sorted by their `Sachnummer` to ensure a stable, predictable ordering.
///
/// Requirements and assumptions:
/// - `XLSXDiff` encapsulates the diff result and exposes:
///   - `added`: a collection of newly added items
///   - `removed`: a collection of removed items
///   - `modified`: a collection of changes with `old`/`new` (or `alt`/`new`) values
///   - `unchanged`: a collection of unchanged items
///   - `hasChanges`: a Boolean indicating whether there are any differences
/// - Inventory items conform to `Identifiable` and provide `Sachnummer` for sorting.
/// - `BestandsobjektRow`, `ModifiedBestandsobjektRow`, and `UnchangedListView` are available to render row content.
/// - This view is intended to be embedded in a `NavigationStack`/`NavigationView` to enable navigation to unchanged items.
///
/// Accessibility and styling:
/// - Background tints use low-opacity system colors to maintain readability.
/// - Section headers include localized German titles and counts for quick scanning.
///
/// - Parameter diff: The computed differences to display.
struct DiffView: View {
    let diff: XLSXDiff

    var body: some View {
        List {
            //MARK: Liste Neuer 'Bestandsobjekte'
            if !diff.added.isEmpty {
                Section("Neu (\(diff.added.count))") {
                    ForEach(diff.added.sorted { $0.Sachnummer < $1.Sachnummer }) { objekt in
                        BestandsobjektRow(objekt: objekt)
                            .listRowBackground(Color.green.opacity(0.08))
                    }
                }
            }
            
            //MARK: Liste Gelöschter 'Bestandsobjekte'
            if !diff.removed.isEmpty {
                Section("Entfernt (\(diff.removed.count))") {
                    ForEach(diff.removed.sorted { $0.Sachnummer < $1.Sachnummer }) { objekt in
                        BestandsobjektRow(objekt: objekt)
                            .listRowBackground(Color.red.opacity(0.08))
                    }
                }
            }

            //MARK: Liste Veränderter 'Bestandsobjekte'
            if !diff.modified.isEmpty {
                Section("Geändert (\(diff.modified.count))") {
                    ForEach(diff.modified.sorted { $0.new.Sachnummer < $1.new.Sachnummer }, id: \.new.id) { change in
                        ModifiedBestandsobjektRow(old: change.alt, new: change.new)
                            .listRowBackground(Color.orange.opacity(0.08))
                    }
                }
            }
            
            //MARK: Link zur Liste der Unveränderten 'Bestandsobjekte'
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

            //MARK: Keine Unterschiede Gefunden
            if !diff.hasChanges {
                Text("Keine Unterschiede gefunden")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
 
#Preview {
    ContentView()
}
