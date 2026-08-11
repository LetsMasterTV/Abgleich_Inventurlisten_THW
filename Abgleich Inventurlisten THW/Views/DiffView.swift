//
//  DiffView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

// Marker für die Positionen im ScrollView-Koordinatensystem
struct NodePositionData: Equatable {
    let id: UUID
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
    
    @State private var showUnchanged = false
    @State private var showDuplicateDetails = false
    
    @State private var showFilters = false
    
    @State private var displayedRoots: [HierarchyNode] = []
    @State private var expanded: Set<UUID> = []
    
    // Breadcrumb-Pfad
    @State private var breadcrumbParts: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Controls mit Such- und Filterleiste
                // Filter & Such-Steuerung
                VStack(spacing: 12) {
                
                    HStack {
                        Toggle("Unveränderte Einträge einblenden", isOn: $showUnchanged)
                        Spacer()
                        Button("▼ Alle", action: expandAll)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                        Button("▲ Keine", action: collapseAll)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                    }
                    
                    Divider()
                    
                    if showFilters {
                        VStack {
                            Picker("Kategorie", selection: $viewModel.selectedCategory) {
                                ForEach(FilterCategory.allCases) { cat in
                                    Text(cat.label).tag(cat)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Toggle("Nur Duplikate", isOn: $viewModel.showOnlyDuplicates)
                                .toggleStyle(.button)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                
            
            
            if diff.hasDuplicateWarnings {
                duplicateWarningBanner
            }
            
            if !diff.hasChanges && !showUnchanged {
                Spacer()
                Text("Keine Unterschiede gefunden")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                // Sticky Breadcrumb Bar
                if !breadcrumbParts.isEmpty {
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
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(displayedRoots) { root in
                            if viewModel.visibleKeys.contains(root.objekt.key) {
                                TreeDisclosureView(node: root, expanded: $expanded, visibleKeys: viewModel.visibleKeys) { node in
                                    AnyView(hierarchyRow(for: node))
                                }
                                
                                Divider()
                                    .padding(.vertical, 4)
                                    .opacity(0.3)
                            }
                        }

                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .coordinateSpace(name: "scrollSpace")
                .onPreferenceChange(NodePositionPreferenceKey.self) { positions in
                    updateBreadcrumbFromPositions(positions)
                }
                .onAppear {
                    rebuildTree()
                }
                .onChange(of: showUnchanged) { _, _ in
                    rebuildTree()
                }
                .onChange(of: viewModel.fullHierarchyRoots) { _, _ in
                    rebuildTree()
                }
                .onChange(of: viewModel.searchText) {
                    viewModel.scheduleRecomputeVisibleKeysDetached()
                }
                .onChange(of: viewModel.selectedCategory) {
                    viewModel.scheduleRecomputeVisibleKeysDetached()
                }
                .onChange(of: viewModel.showOnlyDuplicates) {
                    viewModel.scheduleRecomputeVisibleKeysDetached()
                }
            }
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Beschreibung, Sachnr., Inventarnr., Gerätenr.")
    }
    
    // MARK: - Tree Management
    private func rebuildTree() {
            let fullTree = viewModel.fullHierarchyRoots
            displayedRoots = showUnchanged ? fullTree : pruneToChangesOnly(fullTree)
            expanded = computeInitialExpanded(for: displayedRoots)
            breadcrumbParts = []
        }

    
    private func expandAll() {
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
        let ebenenInt = Int(node.objekt.Ebene) ?? 0
        let ebeneEinrueckung = CGFloat(ebenenInt * 12)
        let istReineHeadline = node.objekt.Beschreibung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
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
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.footnote)
                        .foregroundColor(node.statusIsUnchanged ? .secondary : aktuelleFarbe)
                    
                    Text(node.objekt.key.uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(node.statusIsUnchanged ? .primary : aktuelleFarbe)
                    
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
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(node.statusIsUnchanged ? Color.clear : aktuelleFarbe.opacity(0.10))
                .cornerRadius(4)
                .padding(.leading, ebeneEinrueckung)
                
            } else {
                switch node.status {
                case .added:
                    BestandsobjektRow(objekt: node.objekt)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.18))
                        .cornerRadius(4)
                        .padding(.leading, ebeneEinrueckung)
                    
                case .removed:
                    BestandsobjektRow(objekt: node.objekt)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.18))
                        .cornerRadius(4)
                        .opacity(0.8)
                        .padding(.leading, ebeneEinrueckung)
                    
                case .modified(let old):
                    ModifiedBestandsobjektRow(old: old, new: node.objekt)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(4)
                        .padding(.leading, ebeneEinrueckung)
                    
                case .unchanged:
                    BestandsobjektRow(objekt: node.objekt)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .opacity(showUnchanged ? 1.0 : 0.55)
                        .padding(.leading, ebeneEinrueckung)
                }
            }
        }
        .padding(.vertical, 1)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: NodePositionPreferenceKey.self,
                    value: [NodePositionData(id: node.id, minY: geo.frame(in: .named("scrollSpace")).minY)]
                )
            }
        )
    }
    
    // MARK: - Position & Breadcrumb Calculation
    
    private func updateBreadcrumbFromPositions(_ positions: [NodePositionData]) {
        let visible = positions.filter { $0.minY >= -20 }
        
        guard let topNode = visible.min(by: { $0.minY < $1.minY }) else { return }
        
        computeBreadcrumb(for: topNode.id)
    }
    
    private func computeBreadcrumb(for id: UUID) {
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
    
    private func pathToNode(id: UUID, in roots: [HierarchyNode]) -> [HierarchyNode]? {
        for root in roots {
            if let path = pathRecursive(current: root, targetID: id) {
                return path
            }
        }
        return nil
    }
    
    private func pathRecursive(current: HierarchyNode, targetID: UUID) -> [HierarchyNode]? {
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
}
