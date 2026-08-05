//
//  XLSXViewModel.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//
import SwiftUI
import Foundation

/// Filter-Kategorien für die Darstellung
enum FilterCategory: String, CaseIterable, Identifiable {
    case all
    case added
    case removed
    case modified
    case unchanged
    
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "Alle"
        case .added: return "Neu"
        case .removed: return "Entfernt"
        case .modified: return "Geändert"
        case .unchanged: return "Unverändert"
        }
    }
}

/// Sendable Snapshot eines Knotens für Background-Filterung
private enum StatusSnapshot: Sendable {
    case added
    case removed
    case modified
    case unchanged
}

private struct NodeSnapshot: Sendable {
    let key: String
    let beschreibung: String
    let sachnummer: String
    let inventarnummer: String
    let geraetenummer: String
    let status: StatusSnapshot
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
    into set: inout Set<String>
) -> Bool {
    var anyMatch = false
    for node in nodes {
        let childrenMatch = collectVisibleKeysFromSnapshots(node.children, predicate: predicate, into: &set)
        if predicate(node) || childrenMatch {
            set.insert(node.key)
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

    enum DocumentSlot { case old, new }

    // MARK: - Search & Filter State
    var searchText: String = ""
    var selectedCategory: FilterCategory = .all
    var showOnlyDuplicates: Bool = false

    // MARK: - Visibility & Expansion State
    private(set) var visibleKeysCache: Set<String> = []
    var visibleKeys: Set<String> { visibleKeysCache }

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
        selectedCategory = .all
        showOnlyDuplicates = false
        visibleKeysCache = []
        expandedKeys = []
        visibleKeysTask?.cancel()
    }

    // MARK: - Tree Building
    /// Builds the full hierarchy from current documents and diff
    var fullHierarchyRoots: [HierarchyNode] {
        guard let diff = diff,
              let newItems = newDocument?.inventurliste,
              let oldItems = oldDocument?.inventurliste else { return [] }
        return buildFullHierarchy(newItems: newItems, oldItems: oldItems, diff: diff)
    }

    // MARK: - Visibility Management
    /// Converts HierarchyNode tree into Sendable snapshots for background processing
    private func buildSnapshots(from nodes: [HierarchyNode]) -> [NodeSnapshot] {
        nodes.map { node in
            let statusSnap: StatusSnapshot
            var oldB: String? = nil
            var oldS: String? = nil
            var oldI: String? = nil
            var oldG: String? = nil

            switch node.status {
            case .added:
                statusSnap = .added
            case .removed:
                statusSnap = .removed
            case .modified(let old):
                statusSnap = .modified
                oldB = old.Beschreibung
                oldS = old.Sachnummer
                oldI = old.Inventarnummer
                oldG = old.Geraetenummer
            case .unchanged:
                statusSnap = .unchanged
            }

            return NodeSnapshot(
                key: node.objekt.key,
                beschreibung: node.objekt.Beschreibung,
                sachnummer: node.objekt.Sachnummer,
                inventarnummer: node.objekt.Inventarnummer,
                geraetenummer: node.objekt.Geraetenummer,
                status: statusSnap,
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
        let category = self.selectedCategory
        let onlyDup = self.showOnlyDuplicates
        let dupOld = self.diff?.duplicateKeysOld ?? []
        let dupNew = self.diff?.duplicateKeysNew ?? []

        // Start detached background task
        visibleKeysTask = Task.detached { [snapshots, query, category, onlyDup, dupOld, dupNew] in
            // Debounce sleep (cancellable)
            do {
                try await Task.sleep(nanoseconds: debounceMillis * 1_000_000)
            } catch {
                return
            }

            if Task.isCancelled { return }

            // Build predicate for filtering on snapshots (pure, Sendable)
            let lowerQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

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
                switch category {
                case .all:
                    break
                case .added:
                    if case .added = node.status {} else { return false }
                case .removed:
                    if case .removed = node.status {} else { return false }
                case .modified:
                    if case .modified = node.status {} else { return false }
                case .unchanged:
                    if case .unchanged = node.status {} else { return false }
                }
                // Duplicate filtering
                if onlyDup {
                    if !dupOld.contains(node.key) && !dupNew.contains(node.key) {
                        return false
                    }
                }

                return true
            }

            // FIX: Nutze lokale Variable statt inout-Mutation in Task.detached
            var keys = Set<String>()
            _ = collectVisibleKeysFromSnapshots(snapshots, predicate: predicate, into: &keys)

            if Task.isCancelled { return }

            // Write result back on MainActor
            await MainActor.run {
                self.visibleKeysCache = keys
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
        diff = oldDocument.diff(against: newDocument)
        // Trigger initial visibility computation
        scheduleRecomputeVisibleKeysDetached()
    }
}
