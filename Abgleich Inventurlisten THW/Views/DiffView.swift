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
    let oldItems: [Bestandsobjekt]
    let newItems: [Bestandsobjekt]
 
    @State private var showUnchanged = false
    @State private var showDuplicateDetails = false
    @State private var displayedRoots: [HierarchyNode] = []
    @State private var expanded: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Bestehender Toggle + neue Buttons
            HStack {
                Toggle("Unveränderte Einträge einblenden", isOn: $showUnchanged)
                Spacer()
                Button("▼ Alle", action: expandAll) // Chevron down
                    .font(.caption2)
                    .padding(.horizontal, 4)
                Button("▲ Keine", action: collapseAll) // Chevron up
                    .font(.caption2)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            if diff.hasDuplicateWarnings {
                duplicateWarningBanner
            }

            if !diff.hasChanges && !showUnchanged {
                Spacer()
                Text("Keine Unterschiede gefunden")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(displayedRoots) { root in
                            TreeDisclosureView(node: root, expanded: $expanded) { node in
                                AnyView(hierarchyRow(for: node))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    // Baue den Baum einmal und speichere ihn stable in @State
                    let fullTree = buildFullHierarchy(newItems: newItems, oldItems: oldItems, diff: diff)
                    displayedRoots = showUnchanged ? fullTree : pruneToChangesOnly(fullTree)
                    expanded = computeInitialExpanded(for: displayedRoots)
                }
                .onChange(of: showUnchanged) {
                    // Wenn der Toggle "Unverändert einblenden" geändert wird, updaten
                    let fullTree = buildFullHierarchy(newItems: newItems, oldItems: oldItems, diff: diff)
                    displayedRoots = showUnchanged ? fullTree : pruneToChangesOnly(fullTree)
                    expanded = computeInitialExpanded(for: displayedRoots)
                }
            }
        }
    }
    
    private func expandAll() {
        // Sammle alle Node IDs rekursiv
        var allIds: Set<UUID> = []
        func collect(_ node: HierarchyNode) {
            allIds.insert(node.id)
            for child in node.children { collect(child) }
        }
        for root in displayedRoots { collect(root) }
        expanded = allIds
    }

    private func collapseAll() {
        expanded.removeAll()
    }
    
    private func computeInitialExpanded(for roots: [HierarchyNode]) -> Set<UUID> {
        var toExpand: Set<UUID> = []

        // Markiere alle Ancestors und die Node selbst, wenn die Node oder ein Descendant Status != .unchanged hat
        @discardableResult
        func traverse(_ node: HierarchyNode) -> Bool {
            var hasChange = false
            switch node.status {
            case .added, .removed, .modified:
                hasChange = true
            case .unchanged:
                hasChange = false
            }
            for child in node.children {
                let childHas = traverse(child)
                if childHas { hasChange = true }
            }
            if hasChange {
                // expand this node and all ancestors will be handled via recursion (we add only node here,
                // ancestors will be added when upstream sees that their descendant had change)
                toExpand.insert(node.id)
            }
            return hasChange
        }

        // We also want parents of changed nodes open, so propagate up:
        func markAncestors(_ node: HierarchyNode, ancestors: [HierarchyNode]) {
            var thisHasChange = false
            switch node.status {
            case .added, .removed, .modified:
                thisHasChange = true
            case .unchanged:
                break
            }
            for child in node.children {
                markAncestors(child, ancestors: ancestors + [node])
                if toExpand.contains(child.id) { thisHasChange = true }
            }
            if thisHasChange {
                for a in ancestors { toExpand.insert(a.id) }
                toExpand.insert(node.id)
            }
        }

        for r in roots { traverse(r) }
        for r in roots { markAncestors(r, ancestors: []) }
        return toExpand
    }
 
    @ViewBuilder
    private func hierarchyRow(for node: HierarchyNode) -> some View {
        let ebenenInt = Int(node.objekt.Ebene) ?? 0
        let ebeneEinrueckung = CGFloat(ebenenInt * 12)
        
        // Eine Headline wird erkannt, wenn der Beschreibungstext leer ist
        let istReineHeadline = node.objekt.Beschreibung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // Wir ermitteln die Farbe einmal sauber vorab über ein klares Switch-Statement
        let aktuelleFarbe: Color = {
            switch node.status {
            case .added: return .green
            case .removed: return .red
            case .modified: return .orange
            case .unchanged: return .primary
            }
        }()
        
        Group {
            if istReineHeadline {
                // --- OPTIONALE / MEHRFACHE REINE HEADLINE ---
                HStack(spacing: 6) {
                    // Unterscheidet optisch, ob der Ordner unverändert ist oder Änderungen enthält
                    Image(systemName: "folder.fill")
                        .font(.footnote)
                        .foregroundColor(node.statusIsUnchanged ? .secondary : aktuelleFarbe)
                    
                    Text(node.objekt.key.uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(node.statusIsUnchanged ? .primary : aktuelleFarbe)
                    
                    // Status-Zusatz im THW-Stil auswerten via Switch
                    switch node.status {
                    case .added:
                        Text("[NEUER ABSCHNITT]").font(.caption2).foregroundColor(.green)
                    case .removed:
                        Text("[ENTFERNT]").font(.caption2).foregroundColor(.red)
                    case .modified:
                        Text("[INHALT GEÄNDERT]").font(.caption2).foregroundColor(.orange)
                    case .unchanged:
                        EmptyView()
                    }
                    
                    Spacer()
                }
                .padding(.leading, ebeneEinrueckung)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                // Fehler behoben: Nutzt jetzt die vorbereitete 'aktuelleFarbe'
                .background(node.statusIsUnchanged ? Color.clear : aktuelleFarbe.opacity(0.10))
                .cornerRadius(4)
                
            } else {
                // --- NORMALE BESTANDSOBJEKT-ZEILE ---
                switch node.status {
                case .added:
                    BestandsobjektRow(objekt: node.objekt)
                        .padding(.leading, ebeneEinrueckung)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.18))
                        .cornerRadius(4)
                    
                case .removed:
                    BestandsobjektRow(objekt: node.objekt)
                        .padding(.leading, ebeneEinrueckung)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.18))
                        .cornerRadius(4)
                        .opacity(0.8)
                    
                case .modified(let old):
                    ModifiedBestandsobjektRow(old: old, new: node.objekt)
                        .padding(.leading, ebeneEinrueckung)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(4)
                    
                case .unchanged:
                    BestandsobjektRow(objekt: node.objekt)
                        .padding(.leading, ebeneEinrueckung)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .opacity(showUnchanged ? 1.0 : 0.55)
                }
            }
        }
        .padding(.vertical, 1)
    }

    // Hilfsfunktion zur schnellen Farbzuordnung der Status-Zusätze
    private func statusFarbe(for status: NodeStatus) -> Color {
        switch status {
        case .added: return .green
        case .removed: return .red
        case .modified: return .orange
        case .unchanged: return .primary
        }
    }

    
    private var duplicateWarningBanner: some View {
            let totalCount = diff.duplicateKeysOld.count + diff.duplicateKeysNew.count
     
            return VStack(alignment: .leading, spacing: 4) {
                Button {
                    showDuplicateDetails.toggle()
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(totalCount) Schlüssel nicht eindeutig – Zuordnung kann unsicher sein")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Image(systemName: showDuplicateDetails ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
     
                if showDuplicateDetails {
                    VStack(alignment: .leading, spacing: 2) {
                        if !diff.duplicateKeysOld.isEmpty {
                            Text("In alter Datei:").font(.caption2).foregroundStyle(.secondary)
                            ForEach(Array(diff.duplicateKeysOld).sorted(), id: \.self) { key in
                                Text("• \(key)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        if !diff.duplicateKeysNew.isEmpty {
                            Text("In neuer Datei:").font(.caption2).foregroundStyle(.secondary)
                                .padding(.top, diff.duplicateKeysOld.isEmpty ? 0 : 4)
                            ForEach(Array(diff.duplicateKeysNew).sorted(), id: \.self) { key in
                                Text("• \(key)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))
        }
}

#Preview {
    ContentView()
}
