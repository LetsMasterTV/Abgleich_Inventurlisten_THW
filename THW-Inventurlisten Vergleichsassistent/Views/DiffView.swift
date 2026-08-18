//
//  DiffView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

// Marker für die Positionen im ScrollView-Koordinatensystem
struct NodePositionData: Equatable {
    let id: String
    let minY: CGFloat
}

struct NodePositionPreferenceKey: PreferenceKey {
    static var defaultValue: [NodePositionData] = []
    
    static func reduce(value: inout [NodePositionData], nextValue: () -> [NodePositionData]) {
        value.append(contentsOf: nextValue())
    }
}

struct DiffView: View {
    let diff: XLSXDiff
    let oldItems: [Bestandsobjekt]
    let newItems: [Bestandsobjekt]
    
    @Bindable var viewModel: XLSXViewModel
    
    @State private var showDuplicateDetails = false
    
    @State private var hideUnmatchedProperties = false
    @State private var hideDescriptions = false
    @State private var showFilters = false
    
    @Environment(\.dismiss) var dismiss
    @State private var showingBackAlert = false
    
    @State private var displayedRoots: [HierarchyNode] = []
    @State private var expanded: Set<String> = []
    
    // Breadcrumb-Pfad
    @State private var tracker = BreadcrumbTracker()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Controls mit Such- und Filterleiste
            
            ShowOptionsSection
            
            
            if diff.hasDuplicateWarnings {
                duplicateWarningBanner
            }
            
            if !diff.hasChanges && !viewModel.selectedStatuses.contains(.unchanged) {
                Spacer()
                Text("Keine Unterschiede gefunden")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                // Sticky Breadcrumb Bar
                // Sticky Breadcrumb Bar
                if !tracker.breadcrumbParts.isEmpty {
                    breadCrumpSection
                    
                }
                ScrollSection
            }
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Beschreibung, Sachnr., Inventarnr., Gerätenr.")
        .navigationBarBackButtonHidden(true) // Standard-Zurück-Button ausblenden
        .alert("Vergleich verlassen?", isPresented: $showingBackAlert) {
                    Button("Abbrechen", role: .cancel) { }
                    Button("Verlassen", role: .destructive) {
                        viewModel.reset() // Hier erst Daten löschen
                        dismiss()         // Zurückgehen
                    }
                } message: {
                    Text("Wenn du jetzt zurückgehst, gehen die Vergleichsdaten verloren.")
                }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    // Alert anzeigen statt direkt zu, gehen
                    showingBackAlert = true
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Zurück")
                    }
                }
            }
        }
    }
    
    private var ScrollSection: some View {
        ScrollView(.vertical) {
                LazyVStack(alignment: .leading) {
                    ForEach(displayedRoots) { root in
                        if viewModel.visibleKeys.contains(root.id) {
                            TreeDisclosureView(node: root, expanded: $expanded, visibleKeys: viewModel.visibleKeys) { node in
                                hierarchyRow(for: node)
                            }

                            Divider()
                                .padding(.vertical, 4)
                                .opacity(0.5)
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.top, 10)
                }
            }
            .coordinateSpace(name: "scrollSpace")
            .background(Color(.controlBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
         .coordinateSpace(name: "scrollSpace")
         .onAppear {
             rebuildTree()
             expanded = viewModel.defaultExpandedPruned
         }
         
         .onChange(of: viewModel.searchText) {
             viewModel.scheduleRecomputeVisibleKeysDetached()
         }
         .onChange(of: viewModel.selectedStatuses) {
             withTransaction(Transaction(animation: nil)) {
                 rebuildTree()
             }}
         .onChange(of: viewModel.selectedFilterRegeln) {
             withTransaction(Transaction(animation: nil)) {
                 viewModel.scheduleRecomputeVisibleKeysDetached(debounceMillis: 0)
             }}
     }
    
 
    private var breadCrumpSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Hier greifst du auf tracker.breadcrumbParts zu:
                ForEach(Array(tracker.breadcrumbParts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                        Text(part)
                        .font(.caption.weight(index == tracker.breadcrumbParts.count - 1 ? .bold : .regular))
                        .foregroundStyle(index == tracker.breadcrumbParts.count - 1 ? .primary : .secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            // Dein ursprünglicher Hintergrund / Effekt 1:1 beibehalten:
            .background(.tertiary)
            .padding(.top, 4)
            .padding(.bottom, -5)
    }
    
    private var ShowOptionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Überschriften ausblenden:", isOn: Binding(
                        get: { hideDescriptions },
                        set: { newValue in
                            hideDescriptions = newValue
                            hideUnmatchedProperties = false // Ändert den anderen State
                        }
                    ))
                    .toggleStyle(.switch)
                    .padding(.horizontal, 4)
                Toggle("Unnötige Infos ausblenden:", isOn: Binding(
                        get: { hideUnmatchedProperties },
                        set: { newValue in
                            hideUnmatchedProperties = newValue
                            hideDescriptions = false // Ändert den anderen State
                        }
                    ))
                    .toggleStyle(.switch)
                    .padding(.horizontal, 4)
                Spacer()
                Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showFilters.toggle()
                        }
                            } label: {
                                Label("Filter", systemImage: (showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"))
                            }
                            .padding(.horizontal, 8)
                            .fontWeight(showFilters ? .bold : .regular)
                            .font(.caption2)
                            .help("Filter & Optionen ein-/ausklappen")
                Button("▼ Alle", action: expandAll)
                    .font(.caption2)
                    .padding(.horizontal, 2)
                Button("▲ Keine", action: collapseAll)
                    .font(.caption2)
                    .padding(.horizontal, 2)
            }
            
            if showFilters {
                // Filter & Such-Steuerung
                filterSechtion
            }
            
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        
    }
    
    private var filterSechtion: some View {
        VStack(spacing: 12){
            Divider()
            HStack(spacing: 8) {
                ForEach(FilterStatus.allCases) { status in
                    Toggle(status.rawValue, isOn: Binding(
                        get: { viewModel.selectedStatuses.contains(status) },
                        set: { isSelected in
                            if isSelected {
                                viewModel.selectedStatuses.insert(status)
                            } else {
                                viewModel.selectedStatuses.remove(status)
                            }
                            viewModel.scheduleRecomputeVisibleKeysDetached()
                        }
                    ))
                    .toggleStyle(.switch)
                }
                
            }
            Divider()
            HStack(spacing: 8) {
                Text("Filter: ")
                ForEach(FilterRegeln.allCases) { status in
                    Toggle(status.rawValue, isOn: Binding(
                        get: { viewModel.selectedFilterRegeln.contains(status) },
                        set: { isSelected in
                            if isSelected {
                                viewModel.selectedFilterRegeln.insert(status)
                            } else {
                                viewModel.selectedFilterRegeln.remove(status)
                            }
                            viewModel.scheduleRecomputeVisibleKeysDetached()
                        }
                    ))
                    .toggleStyle(.button)
                }
                
            }
        }
    }
    
    private func rebuildTree() {
        // Prüfen, ob der User "Unverändert" im Filter-Set hat
        if viewModel.selectedStatuses.contains(.unchanged) {
            displayedRoots = viewModel.fullHierarchyRoots
        } else {
            // Performance-Booster: Schlanken Baum ohne unveränderte Zweige nutzen
            displayedRoots = viewModel.prunedHierarchyRoots
        }
        tracker.breadcrumbParts = []
    }
    private func expandAll() {
        var allIds: Set<String> = []
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
    
    private func computeInitialExpanded(for roots: [HierarchyNode]) -> Set<String> {
        var toExpand: Set<String> = []
        
        if viewModel.selectedStatuses.contains(.unchanged) {
                // Wir klappen einfach nur die Haupt-Kategorien (Ebene 0) auf.
                // Das geht in 1 Millisekunde statt in 2 Sekunden.
                for root in roots {
                    toExpand.insert(root.id)
                }
                return toExpand
            }
        
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
                toExpand.insert(node.id)
            }
            return hasChange
        }
        
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
        
        for r in roots { _ = traverse(r) }
        for r in roots { markAncestors(r, ancestors: []) }
        return toExpand
    }
    
    // MARK: - Row Rendering
    
    @ViewBuilder
    private func hierarchyRow(for node: HierarchyNode) -> some View {

        let unMatched = !viewModel.matchedKeys.contains(node.id) && hideUnmatchedProperties
        
        Group {
            switch node.status {
            case .added:
                BestandsobjektRow(objekt: node.objekt, hideDescription: hideDescriptions, hideProperties: unMatched)
                
            case .removed:
                BestandsobjektRow(objekt: node.objekt, hideDescription: hideDescriptions, hideProperties: unMatched)
                    .opacity(0.8)
                
            case .modified(let old):
                ModifiedBestandsobjektRow(old: old, new: node.objekt, hideDescription: hideDescriptions, hideProperties: unMatched)
                
            case .unchanged:
                BestandsobjektRow(objekt: node.objekt, hideDescription: hideDescriptions, hideProperties: unMatched)
                    .opacity(viewModel.selectedStatuses.contains(.unchanged) ? 1.0 : 0.55)
            }
        }
        .background(node.children.isEmpty ? rowColor(for: node) : Color.clear)
        .cornerRadius(6)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named("scrollSpace")).minY
        } action: { newMinY in
            tracker.updatePosition(id: node.id, minY: newMinY, node: node)
        }
        .onDisappear {
            tracker.removeNode(id: node.id)
        }
    }
    
   


    // MARK: - Position & Breadcrumb Calculation
    
    
    
    
    // MARK: - Subviews
    
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
    
    
    private struct PositionTrackingModifier: ViewModifier {
        let nodeID: String
        let track: Bool
        
        func body(content: Content) -> some View {
            if track {
                content.background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: NodePositionPreferenceKey.self,
                            value: [NodePositionData(id: nodeID, minY: geo.frame(in: .named("scrollSpace")).minY)]
                        )
                    }
                )
            } else {
                content
            }
        }
    }
}
