//
//  XLSXViewModel.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//
import SwiftUI
import Foundation

enum FilterStatus: String, CaseIterable, Identifiable, Sendable, Equatable {
    case added = "Neu:"
    case removed = "Entfernt:"
    case modified = "Geändert:"
    case unchanged = "Unverändert:"
    
    var id: String { rawValue }
    
    nonisolated static func == (lhs: FilterStatus, rhs: FilterStatus) -> Bool {
        switch (lhs, rhs) {
        case (.added, .added): return true
        case (.removed, .removed): return true
        case (.modified, .modified): return true
        case (.unchanged, .unchanged): return true
        default: return false
        }
    }
}

enum FilterRegeln: String, CaseIterable, Identifiable, Sendable {
    case Fremdbeschafft = "Fremdbeschafft"
    case ueberSTAN = "Überbestand"
    case Fehlt = "Fehlt"
    case ursprünglich = "Veraltet"
    case verfuegbar = "Verfügbar"
    case nichtverfuegbar = "nicht Verfügbar"
    case Ausgetauscht = "Ausgetauscht"
    case teilweise = "Teilweise"
    
    var id: String {rawValue}
}

private struct FilterFlags: OptionSet, Sendable {
    let rawValue: UInt16

    static let fremdbeschafft   = FilterFlags(rawValue: 1 << 0)
    static let ueberSTAN        = FilterFlags(rawValue: 1 << 1)
    static let fehlt            = FilterFlags(rawValue: 1 << 2)
    static let urspruenglich    = FilterFlags(rawValue: 1 << 3)
    static let verfuegbar       = FilterFlags(rawValue: 1 << 4)
    static let nichtverfuegbar  = FilterFlags(rawValue: 1 << 5)
    static let ausgetauscht     = FilterFlags(rawValue: 1 << 6)
    static let teilweise        = FilterFlags(rawValue: 1 << 7)
}
/// Sendable Snapshot eines Knotens für Background-Filter

private struct NodeSnapshot: Sendable {
    let id: String
    let itemkey: String
    let beschreibung: String
    let fremdbeschaft: String
    let filterFlags: FilterFlags
    let sachnummer: String
    let inventarnummer: String
    let geraetenummer: String
    let status: FilterStatus
    let oldBeschreibung: String?
    let oldSachnummer: String?
    let oldInventarnummer: String?
    let oldGeraetenummer: String?
    let children: [NodeSnapshot]
    let searchableFields: [String]
}

/// Pure Value Funktion: Rekursiv sichtbare Keys aus Snapshots sammeln
/// @Sendable damit die Funktion in Task.detached nutzbar ist
private func collectVisibleKeysFromSnapshots(
    _ nodes: [NodeSnapshot],
    predicate: @Sendable (NodeSnapshot) -> Bool,
    visibleKeys: inout Set<String>,
    matchedKeys: inout Set<String>
) -> Bool {

    var anyMatch = false

    for node in nodes {

        // Passt dieses Bestandsobjekt selbst?
        let selfMatches = predicate(node)

        // Prüfen, ob eines der Kinder passt
        // Passt dieses Bestandsobjekt selbst?

        // Prüfen, ob eines der Kinder passt
        let childrenMatch = collectVisibleKeysFromSnapshots(
            node.children,
            predicate: predicate,
            visibleKeys: &visibleKeys,
            matchedKeys: &matchedKeys
        )

        // Nur wenn das Objekt SELBST matched,
        // kommt es in matchedKeys.
        if selfMatches {
            matchedKeys.insert(node.id)
        }

        // Für die bestehende Baumdarstellung bleibt
        // das Objekt sichtbar, wenn es selbst oder ein
        // Kind matched.
        if selfMatches || childrenMatch {
            visibleKeys.insert(node.id)
            anyMatch = true
        }
    }

    return anyMatch
}

/// A SwiftUI-observable view model that coordinates loading, parsing, diffing, and filtering of two XLSX-based inventory documents.
///
/// XLSXViewModel is responsible for:
/// - Accepting raw XLSX data for two document "slots" (old and new),
/// - Parsing that data into `Inventurliste` domain models,
/// - Computing an `XLSXDiff` between the two documents when both are available,
/// - Maintaining search/filter state and computing visible keys asynchronously in background,
/// - Managing expand/collapse state per node (using stable `objekt.key`),
/// - Exposing any parse or processing errors via a user-presentable message.
///
/// Usage:
/// - Call `load(data:as:)` with XLSX file data and the corresponding `DocumentSlot` (.old or .new).
/// - Once both slots are loaded successfully, the model automatically recomputes the `diff`.
/// - Modify `searchText`, `selectedCategory`, or `showOnlyDuplicates` to trigger async recomputation of visible keys.
/// - Access `diff`, `fullHierarchyRoots`, and `visibleKeys` to populate views.
/// - Use `isExpanded(_:)`, `toggleExpanded(_:)` to manage node visibility per key.
/// - Call `reset()` to clear all state and start over.
@MainActor
@Observable
class XLSXViewModel {
    // MARK: - Document Loading
    var oldDocument: Inventurliste?
    var newDocument: Inventurliste?
    var diff: XLSXDiff?
    var errorMessage: String?

    private(set) var fullHierarchyRoots: [HierarchyNode] = []
    private(set) var prunedHierarchyRoots: [HierarchyNode] = []
    
    private(set) var defaultExpandedFull: Set<String> = []
    private(set) var defaultExpandedPruned: Set<String> = []
    
    enum DocumentSlot { case old, new }

    // MARK: - Search & Filter State
    var searchText: String = ""
    var selectedStatuses: Set<FilterStatus> = [.added, .removed, .modified]
    var selectedFilterRegeln: Set<FilterRegeln> = []

    var showOnlyDuplicates: Bool = false

    // MARK: - Visibility & Expansion State
    private(set) var visibleKeysCache: Set<String> = []
    var visibleKeys: Set<String> { visibleKeysCache }

    private(set) var matchedKeysCache: Set<String> = []
    var matchedKeys: Set<String> { matchedKeysCache }
    
    private var filterSnapshots: [NodeSnapshot] = []
    
    private(set) var expandedKeys: Set<String> = []

    // MARK: - Background Task Management
    private var visibleKeysTask: Task<Void, Never>?
    
    // MARK: - Loading
    func load(data: Data, as slot: DocumentSlot) {
        errorMessage = nil
        
            do {
                let document =
                    try Inventurliste(data: data)
                
                
                switch slot {
                case .old:
                    oldDocument = document
                case .new:
                    newDocument = document
                }
                
                guard let oldDocument, let newDocument else {
                    return
                }
                
                let newDiff = try oldDocument.diff(against: newDocument)
              
                
                
                apply(diff: newDiff)
            } catch {
                errorMessage = "Fehler beim Parsen: \(error.localizedDescription)"
            
        }
    }
    // MARK: - Reset
    func reset() {
        oldDocument = nil
        newDocument = nil
        diff = nil
        errorMessage = nil
        searchText = ""
        selectedStatuses = [.added, .removed, .modified]
        selectedFilterRegeln = []
        showOnlyDuplicates = false
        visibleKeysCache = []
        matchedKeysCache = []
        expandedKeys = []
        fullHierarchyRoots = []
        visibleKeysTask?.cancel()
        filterSnapshots.removeAll()
    }
   

    // MARK: - Visibility Management
    /// Converts HierarchyNode tree into Sendable snapshots for background processing
    private func buildSnapshots(from nodes: [HierarchyNode]) -> [NodeSnapshot] {
        nodes.map { node in
            
            let FilterStatus: FilterStatus
            var oldB: String?
            var oldS: String?
            var oldI: String?
            var oldG: String?
            
            // 1. Status und alte Werte sauber über Pattern Matching extrahieren
            switch node.status {
            case .added:
                FilterStatus = .added
            case .removed:
                FilterStatus = .removed
            case .modified(let oldObj):
                // Hier entpacken wir das assoziierte alte Objekt!
                FilterStatus = .modified
                oldB = oldObj.Beschreibung
                oldS = oldObj.Sachnummer
                oldI = oldObj.Inventarnummer
                oldG = oldObj.Geraetenummer
            case .unchanged:
                FilterStatus = .unchanged
            }
            
            // 2. Thread-sicheren Snapshot für den Hintergrund-Task erstellen
            return NodeSnapshot(
                id: node.id,
                itemkey: node.objekt.key,
                beschreibung: node.objekt.Beschreibung,
                fremdbeschaft: node.objekt.Fremdbeschafft,
                filterFlags: makeFilterFlags(
                    status: node.objekt.Status,
                    fremdbeschafft: node.objekt.Fremdbeschafft
                ),
                sachnummer: node.objekt.Sachnummer,
                inventarnummer: node.objekt.Inventarnummer,
                geraetenummer: node.objekt.Geraetenummer,
                status: FilterStatus,
                oldBeschreibung: oldB,
                oldSachnummer: oldS,
                oldInventarnummer: oldI,
                oldGeraetenummer: oldG,
                children: buildSnapshots(from: node.children),
                searchableFields: [
                    node.objekt.Beschreibung.lowercased(),
                    node.objekt.Sachnummer.lowercased(),
                    node.objekt.Inventarnummer.lowercased(),
                    node.objekt.Geraetenummer.lowercased(),
                    oldB?.lowercased() ?? "",
                    oldS?.lowercased() ?? "",
                    oldI?.lowercased() ?? "",
                    oldG?.lowercased() ?? ""
                ]
            )
        }
    }

    /// Schedules async, debounced recomputation of visible keys on a background task
    /// Call this when searchText/selectedCategory/showOnlyDuplicates changed
    func scheduleRecomputeVisibleKeysDetached(debounceMillis: UInt64 = 250) {
        // Cancel previous task
        visibleKeysTask?.cancel()

        // Build snapshot on MainActor (safe access to HierarchyNode objects)
        let snapshots = self.filterSnapshots

        // Capture filter state as Sendable copies
        let query = self.searchText
        let activeFilterRegeln = self.selectedFilterRegeln
        let activeStatuses = self.selectedStatuses
       

        // Start detached background task
        visibleKeysTask = Task.detached { [snapshots, query, activeStatuses, activeFilterRegeln] in
            // Debounce sleep (cancellable)
            do {
                try await Task.sleep(nanoseconds: debounceMillis * 1_000_000)
            } catch {
                return
            }

            if Task.isCancelled { return }

            // Build predicate for filtering on snapshots (pure, Sendable)
            let lowerQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            let activeFilterFlags = activeFilterRegeln.reduce(into: FilterFlags()) {
                switch $1 {
                case .Fremdbeschafft:
                    $0.insert(.fremdbeschafft)
                case .ueberSTAN:
                    $0.insert(.ueberSTAN)
                case .Fehlt:
                    $0.insert(.fehlt)
                case .ursprünglich:
                    $0.insert(.urspruenglich)
                case .verfuegbar:
                    $0.insert(.verfuegbar)
                case .nichtverfuegbar:
                    $0.insert(.nichtverfuegbar)
                case .Ausgetauscht:
                    $0.insert(.ausgetauscht)
                case .teilweise:
                    $0.insert(.teilweise)
                }
            }
            if lowerQuery.isEmpty &&
               activeStatuses == [.added, .removed, .modified] &&
               activeFilterRegeln.isEmpty {

                var allKeys = Set<String>()
                var matchedKeys = Set<String>()

                func collectAll(from nodes: [NodeSnapshot]) {
                    for node in nodes {

            allKeys.insert(node.id)

            // Bei komplett deaktivierten Zusatzfiltern
            // entsprechen die Matches den Statusfiltern.
            switch node.status {
            case .added:
                if activeStatuses.contains(.added) {
                    matchedKeys.insert(node.id)
                }

            case .removed:
                if activeStatuses.contains(.removed) {
                    matchedKeys.insert(node.id)
                }

            case .modified:
                if activeStatuses.contains(.modified) {
                    matchedKeys.insert(node.id)
                }

            case .unchanged:
                if activeStatuses.contains(.unchanged) {
                    matchedKeys.insert(node.id)
                }
            }

            collectAll(from: node.children)
        }
    }

    collectAll(from: snapshots)

    if !Task.isCancelled {
        await MainActor.run {
            self.visibleKeysCache = allKeys
            self.matchedKeysCache = matchedKeys
        }
    }

    return
}

        
            let predicate: @Sendable (NodeSnapshot) -> Bool = { node in
                // 1. Suchtext-Prüfung
                
                
                // 2. Kategorie-Filter
                let matchesStatus: Bool = {
                            switch node.status {
                            case .added: return activeStatuses.contains(.added)
                            case .removed: return activeStatuses.contains(.removed)
                            case .modified: return activeStatuses.contains(.modified)
                            case .unchanged: return activeStatuses.contains(.unchanged)
                            }
                        }()
                        if !matchesStatus { return false }

                
                if !activeFilterFlags.isEmpty &&
                    !node.filterFlags.isSuperset(of: activeFilterFlags) {
                    return false
                }
                
                if !lowerQuery.isEmpty {
                    let matchesSearch = node.searchableFields.contains {
                        $0.contains(lowerQuery)
                    }
                    
                    // Wenn der Suchbegriff in keinem Feld vorkommt -> Element sofort aussortieren!
                    if !matchesSearch {
                        return false
                    }
                }
                
                return true
            }
            
            

            // FIX: Nutze lokale Variable statt inout-Mutation in Task.detached
            var visibleKeys = Set<String>()
            var matchedKeys = Set<String>()

            _ = collectVisibleKeysFromSnapshots(
                snapshots,
                predicate: predicate,
                visibleKeys: &visibleKeys,
                matchedKeys: &matchedKeys
            )

            if Task.isCancelled { return }

            // Write result back on MainActor
            await MainActor.run {
                self.visibleKeysCache = visibleKeys
                self.matchedKeysCache = matchedKeys
            }
        }
    }

    private func makeFilterFlags(
        status: String,
        fremdbeschafft: String
    ) -> FilterFlags {

        var result: FilterFlags = []

        let separators = CharacterSet(charactersIn: ",;/ ")

        for code in status
            .components(separatedBy: separators)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .filter({ !$0.isEmpty })
        {
            switch code {
            case "F":
                result.insert(.fehlt)
            case "U":
                result.insert(.urspruenglich)
            case "ÜB":
                result.insert(.ueberSTAN)
            case "T":
                result.insert(.teilweise)
            case "A":
                result.insert(.ausgetauscht)
            case "NV":
                result.insert(.nichtverfuegbar)
                continue
            case "V":
                result.insert(.verfuegbar)
            default:
                break
            }
        }

        if !fremdbeschafft.isEmpty {
            result.insert(.fremdbeschafft)
        }

        return result
    }
    
    // MARK: - Expansion State Management
    func isExpanded(_ key: String) -> Bool {
        expandedKeys.contains(key)
    }

    func setExpanded(_ key: String, _ expanded: Bool) {
        if expanded {
            expandedKeys.insert(key)
        } else {
            expandedKeys.remove(key)
        }
    }

    func toggleExpanded(_ key: String) {
        if expandedKeys.contains(key) {
            expandedKeys.remove(key)
        } else {
            expandedKeys.insert(key)
        }
    }

    // MARK: - Private Helpers

    private func recomputeDiffIfPossible() {
            guard let oldDocument, let newDocument else { return }

            let newDiff = oldDocument.diff(against: newDocument)
            diff = newDiff

            // 1. Vollständigen Baum erstellen
            fullHierarchyRoots = buildFullHierarchy(
                newItems: newDocument.inventurliste,
                oldItems: oldDocument.inventurliste,
                diff: newDiff
            )

            // 2. Reduzierten Baum & Aufklapp-Keys in EINEM Durchlauf berechnen
            let (pruned, prunedExpanded, matchedkeys) = pruneToChangesOnly(fullHierarchyRoots)
            prunedHierarchyRoots = pruned
            defaultExpandedPruned = prunedExpanded
            
            matchedKeysCache = matchedkeys

            // 3. Für den vollen Baum nur die Hauptkategorien (Ebene 0) aufklappen
            defaultExpandedFull = Set(fullHierarchyRoots.map(\.id))

            scheduleRecomputeVisibleKeysDetached()
        }
    
    @MainActor
    private func apply(diff newDiff: XLSXDiff) {
        guard let oldDocument, let newDocument else { return }

        diff = newDiff

        fullHierarchyRoots = buildFullHierarchy(
            newItems: newDocument.inventurliste,
            oldItems: oldDocument.inventurliste,
            diff: newDiff
        )

        let (pruned, prunedExpanded, matchedkeys) =
            pruneToChangesOnly(fullHierarchyRoots)

        prunedHierarchyRoots = pruned
        defaultExpandedPruned = prunedExpanded
        matchedKeysCache = matchedkeys
        defaultExpandedFull = Set(fullHierarchyRoots.map(\.id))

        filterSnapshots = buildSnapshots(from: fullHierarchyRoots)

        scheduleRecomputeVisibleKeysDetached()
    }
}
