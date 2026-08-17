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

/// Sendable Snapshot eines Knotens für Background-Filter

private struct NodeSnapshot: Sendable {
    let id: String
    let itemkey: String
    let beschreibung: String
    let fremdbeschaft: String
    let StatusObjekt: String
    let sachnummer: String
    let inventarnummer: String
    let geraetenummer: String
    let status: FilterStatus
    let oldBeschreibung: String?
    let oldSachnummer: String?
    let oldInventarnummer: String?
    let oldGeraetenummer: String?
    let children: [NodeSnapshot]
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
    
    private(set) var expandedKeys: Set<String> = []

    // MARK: - Background Task Management
    private var visibleKeysTask: Task<Void, Never>?

    // MARK: - Loading
    func load(data: Data, as slot: DocumentSlot) {
        errorMessage = nil
        do {
            let document = try Inventurliste(data: data)
            switch slot {
            case .old: oldDocument = document
            case .new: newDocument = document
            }
            recomputeDiffIfPossible()
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
        expandedKeys = []
        fullHierarchyRoots = []
        visibleKeysTask?.cancel()
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
                StatusObjekt: node.objekt.Status,
                sachnummer: node.objekt.Sachnummer,
                inventarnummer: node.objekt.Inventarnummer,
                geraetenummer: node.objekt.Geraetenummer,
                status: FilterStatus,
                oldBeschreibung: oldB,
                oldSachnummer: oldS,
                oldInventarnummer: oldI,
                oldGeraetenummer: oldG,
                children: buildSnapshots(from: node.children)
            )
        }
    }

    /// Schedules async, debounced recomputation of visible keys on a background task
    /// Call this when searchText/selectedCategory/showOnlyDuplicates changed
    func scheduleRecomputeVisibleKeysDetached(debounceMillis: UInt64 = 250) {
        // Cancel previous task
        visibleKeysTask?.cancel()

        // Build snapshot on MainActor (safe access to HierarchyNode objects)
        let roots = self.fullHierarchyRoots
        let snapshots = buildSnapshots(from: roots)

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

            if lowerQuery.isEmpty && activeStatuses == [.added,.removed,.modified] && activeFilterRegeln == [] {
            // Einfach alle vorhandenen Keys übernehmen statt rekursiv zu filtern!
            var allKeys = Set<String>()
            func collectAll(from nodes: [NodeSnapshot]) {
                for n in nodes {
                    allKeys.insert(n.id)
                    collectAll(from: n.children)
                }
            }
            collectAll(from: snapshots)
            
            if !Task.isCancelled {
                await MainActor.run { self.visibleKeysCache = allKeys }
            }
            return
        }
            let predicate: @Sendable (NodeSnapshot) -> Bool = { node in
                // 1. Suchtext-Prüfung
                if !lowerQuery.isEmpty {
                    let matchesSearch = node.beschreibung.lowercased().contains(lowerQuery) ||
                                        node.sachnummer.lowercased().contains(lowerQuery) ||
                                        node.inventarnummer.lowercased().contains(lowerQuery) ||
                                        node.geraetenummer.lowercased().contains(lowerQuery) ||
                                        (node.oldBeschreibung?.lowercased().contains(lowerQuery) ?? false) ||
                                        (node.oldSachnummer?.lowercased().contains(lowerQuery) ?? false) ||
                                        (node.oldInventarnummer?.lowercased().contains(lowerQuery) ?? false) ||
                                        (node.oldGeraetenummer?.lowercased().contains(lowerQuery) ?? false)
                    
                    // Wenn der Suchbegriff in keinem Feld vorkommt -> Element sofort aussortieren!
                    if !matchesSearch {
                        return false
                    }
                }
                
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

                let matchFilter: Bool = {
                    // Keine FilterRegel ausgewählt -> alles anzeigen
                    if activeFilterRegeln.isEmpty { return true }

                    // Zelle in einzelne Status-Codes zerlegen (Trenner: Komma, Semikolon, Schrägstrich, Leerzeichen)
                    let separators = CharacterSet(charactersIn: ",;/ ")
                    let codes = node.StatusObjekt
                        .components(separatedBy: separators)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    var matched: Set<FilterRegeln> = []

                    for code in codes {
                        switch code {
                        case "F":  matched.insert(.Fehlt)
                        case "U":  matched.insert(.ursprünglich)
                        case "ÜB": matched.insert(.ueberSTAN)
                        case "NV": matched.insert(.nichtverfuegbar)
                        case "V":  matched.insert(.verfuegbar)
                        case "T":  matched.insert(.teilweise)
                        case "A":  matched.insert(.Ausgetauscht)
                        default: break
                        }
                    }

                    if !node.fremdbeschaft.isEmpty {
                        matched.insert(.Fremdbeschafft)
                    }

                    // Anzeigen, sobald mindestens eine Bedingung erfüllt ist
                    return !activeFilterRegeln.isDisjoint(with: matched)
                }()
                if !matchFilter { return false }
                
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
}
