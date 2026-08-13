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
    
    @State private var hideDescriptions = false
    @State private var showFilters = false
    
    @State private var displayedRoots: [HierarchyNode] = []
    @State private var expanded: Set<String> = []
    
    // Breadcrumb-Pfad
    @State private var breadcrumbParts: [String] = []
    @State private var nodePositions: [String: CGFloat] = [:]
    
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
                if !breadcrumbParts.isEmpty {
                    breadCrumpSection
                    
                    Divider()
                }
                
                // Eigentliche ScrollView
                ScrollView {
                    ScrollSection
                }
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
            }
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Beschreibung, Sachnr., Inventarnr., Gerätenr.")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showFilters.toggle()
                    }
                } label: {
                    Label("Filter", systemImage: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help("Filter & Optionen ein-/ausklappen")
            }
        }
    }
    
    private var ScrollSection: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(displayedRoots) { root in
                if viewModel.visibleKeys.contains(root.id) {
                    TreeDisclosureView(node: root, expanded: $expanded, visibleKeys: viewModel.visibleKeys) { node in
                        hierarchyRow(for: node)
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                        .opacity(0.3)
                }
            }
            .padding(.leading, 10)
            
        }
        .background(Color(.controlBackgroundColor))
        
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        .padding(.vertical, 12)

    }
    
 
    private var breadCrumpSection: some View {
        HStack(spacing: 6) {
            ForEach(Array(breadcrumbParts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                
                Text(part)
                    .font(.caption.weight(index == breadcrumbParts.count - 1 ? .bold : .regular))
                    .foregroundStyle(index == breadcrumbParts.count - 1 ? .primary : .secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
    
    private var ShowOptionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Überschriften ausblenden", isOn: $hideDescriptions)
                    .toggleStyle(.switch)
                Spacer()
                Button("▼ Alle", action: expandAll)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                Button("▲ Keine", action: collapseAll)
                    .font(.caption2)
                    .padding(.horizontal, 4)
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
            
            HStack(spacing: 16) {
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
                                        .toggleStyle(.button)
                                    }
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
        breadcrumbParts = []
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
        
        Group {
            switch node.status {
            case .added:
                BestandsobjektRow(objekt: node.objekt, hideDescription: hideDescriptions)
                
            case .removed:
                BestandsobjektRow(objekt: node.objekt, hideDescription: hideDescriptions)
                    .opacity(0.8)
                
            case .modified(let old):
                ModifiedBestandsobjektRow(old: old, new: node.objekt, hideDescription: hideDescriptions)
                
            case .unchanged:
                BestandsobjektRow(objekt: node.objekt, hideDescription: hideDescriptions)
                    .opacity(viewModel.selectedStatuses.contains(.unchanged) ? 1.0 : 0.55)
            }
        }
        .background(node.children.isEmpty ? rowColor(for: node) : Color.clear)
        .cornerRadius(6)
        .padding(.vertical, 2)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named("scrollSpace")).minY
        } action: { newMinY in
            nodePositions[node.id] = newMinY
            updateBreadcrumbFromTracker()
        }
        .onDisappear {
            nodePositions.removeValue(forKey: node.id)
        }
    }
    
   


    // MARK: - Position & Breadcrumb Calculation
    
    
    private func updateBreadcrumbFromTracker() {
        guard !nodePositions.isEmpty else { return }

        let passed = nodePositions.filter { $0.value <= 20 }
        let topID = passed.max(by: { $0.value < $1.value })?.key
            ?? nodePositions.min(by: { $0.value < $1.value })?.key

        guard let topID else { return }
        computeBreadcrumb(for: topID)
    }
    
    private func computeBreadcrumb(for id: String) {
        guard let path = pathToNode(id: id, in: displayedRoots) else {
            return
        }
        
        let parts = path.map { node -> String in
            let beschr = node.objekt.Beschreibung.trimmingCharacters(in: .whitespacesAndNewlines)
            return beschr.isEmpty ? node.objekt.key : beschr
        }
        
        if breadcrumbParts != parts {
            breadcrumbParts = parts
        }
    }
    
    private func pathToNode(id: String, in roots: [HierarchyNode]) -> [HierarchyNode]? {
        for root in roots {
            if let path = pathRecursive(current: root, targetID: id) {
                return path
            }
        }
        return nil
    }
    
    private func pathRecursive(current: HierarchyNode, targetID: String) -> [HierarchyNode]? {
        if current.id == targetID {
            return [current]
        }
        for child in current.children {
            if let subpath = pathRecursive(current: child, targetID: targetID) {
                var p = [current]
                p.append(contentsOf: subpath)
                return p
            }
        }
        return nil
    }
    
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
