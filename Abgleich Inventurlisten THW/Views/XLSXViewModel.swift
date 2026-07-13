//
//  XLSXViewModel.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//
import SwiftUI
import Foundation

/// A SwiftUI-observable view model that coordinates loading, parsing, and diffing of two XLSX-based inventory documents.
///
/// XLSXViewModel is responsible for:
/// - Accepting raw XLSX data for two document "slots" (old and new),
/// - Parsing that data into `Inventurliste` domain models,
/// - Computing an `XLSXDiff` between the two documents when both are available,
/// - Exposing any parse or processing errors via a user-presentable message.
///
/// Usage:
/// - Call `load(data:as:)` with XLSX file data and the corresponding `DocumentSlot` (.old or .new).
/// - Once both slots are loaded successfully, the model automatically recomputes the `diff`.
/// - Access `diff` to display changes, or `errorMessage` to present parsing issues.
/// - Call `reset()` to clear all state and start over.
///
/// Threading:
/// - Designed for use on the main actor via SwiftUI; ensure UI updates occur on the main thread.
///
/// Dependencies:
/// - Relies on `Inventurliste` for parsing XLSX data and providing a `diff(against:)` operation.
/// - Uses `XLSXDiff` to represent computed differences between two inventories.
///
/// Properties:
/// - `oldDocument`: The previously saved or baseline `Inventurliste`.
/// - `newDocument`: The newly imported `Inventurliste` to compare against the old one.
/// - `diff`: The computed difference between `oldDocument` and `newDocument`, if both are available.
/// - `errorMessage`: A human-readable description of the most recent error, suitable for UI display.
///
/// Methods:
/// - `load(data:as:)`: Parses XLSX data into an `Inventurliste` and assigns it to the specified slot. Automatically triggers diff recomputation if both slots are filled. Sets `errorMessage` on failure.
/// - `reset()`: Clears documents, diff, and error state to return the model to its initial state.
///
/// Nested Types:
/// - `DocumentSlot`: Designates which document slot to populate (`.old` or `.new`).
///
/// Side Effects:
/// - Prints diagnostic information to the console during loading and parsing.
/// - Updates observable properties to drive SwiftUI views.
///
/// Error Handling:
/// - Parsing errors are caught and reported via `errorMessage`. The property is cleared on each new `load` attempt.
///
/// Example:
/// - After selecting two XLSX files (old and new), call `load(data:as:)` for each. Bind your UI to `diff` to present changes and to `errorMessage` for error alerts.
@Observable
class XLSXViewModel {
    var oldDocument: Inventurliste?
    var newDocument: Inventurliste?
    var diff: XLSXDiff?
    var errorMessage: String?
 
    /// Loads XLSX data into the specified document slot and updates the model state.
    ///
    /// This method attempts to parse the provided XLSX `data` into an `Inventurliste`
    /// and assigns it to the given `slot` (.old or .new). If parsing succeeds, the method
    /// automatically triggers a recomputation of the `diff` if both the old and new
    /// documents are available. If parsing fails, a user-presentable `errorMessage` is set.
    ///
    /// Behavior:
    /// - Clears any existing `errorMessage` at the start of the operation.
    /// - Parses XLSX data into an `Inventurliste`.
    /// - Assigns the parsed document to the indicated `slot`.
    /// - Recomputes `diff` when both documents are present.
    /// - On failure, logs the error and sets `errorMessage` with a localized description.
    ///
    /// Threading:
    /// - Intended to be called on the main actor within SwiftUI-driven flows, as it mutates
    ///   observable state used by the UI.
    ///
    /// - Parameters:
    ///   - data: The raw XLSX file contents to parse.
    ///   - slot: The destination slot to populate, either `.old` (baseline) or `.new` (comparison).
    ///
    /// - Postconditions:
    ///   - On success: `oldDocument` or `newDocument` is updated, and `diff` may be recomputed.
    ///   - On failure: `errorMessage` contains a human-readable description of the parsing issue.
    ///
    /// - SeeAlso: `reset()`, `recomputeDiffIfPossible()`, `Inventurliste`, `XLSXDiff`
    func load(data: Data, as slot: DocumentSlot) {
        errorMessage = nil
        print("▶️ load() aufgerufen für Slot: \(slot), Datengröße: \(data.count) Bytes")
        do {
            let document = try Inventurliste(data: data)
            print("✅ \(document.inventurliste.count) Produkte")
            switch slot {
            case .old: oldDocument = document
            case .new: newDocument = document
            }
            recomputeDiffIfPossible()
        } catch {
            print("❌ Parse-Fehler: \(error)")
            errorMessage = "Fehler beim Parsen (\(slot)): \(error.localizedDescription)"
        }
    }
 
    enum DocumentSlot { case old, new }
 
    /// Recomputes the diff between the currently loaded documents if both are available.
    ///
    /// Behavior:
    /// - If both `oldDocument` and `newDocument` are non-nil, computes and assigns a new `XLSXDiff`
    ///   by calling `oldDocument.diff(against: newDocument)`.
    /// - If either document is missing, the method returns without modifying `diff`.
    ///
    /// Side Effects:
    /// - Updates the observable `diff` property, triggering SwiftUI view updates.
    ///
    /// Threading:
    /// - Intended to be called on the main actor as part of UI-driven workflows.
    ///
    /// Preconditions:
    /// - `oldDocument` and `newDocument` should be successfully parsed `Inventurliste` instances.
    ///
    /// Postconditions:
    /// - `diff` reflects the latest comparison of `oldDocument` vs `newDocument` when both are present;
    ///   otherwise, `diff` remains unchanged.
    ///
    /// Usage:
    /// - Automatically invoked by `load(data:as:)` after assigning a document slot.
    /// - Can be called manually if either document is updated and a fresh diff is needed.
    private func recomputeDiffIfPossible() {
        guard let oldDocument, let newDocument else { return }
        diff = oldDocument.diff(against: newDocument)
    }
    
    /// Resets the view model to its initial state by clearing all loaded data and computed results.
    ///
    /// Calling this method:
    /// - Sets `oldDocument` and `newDocument` to `nil`, removing any previously parsed inventories.
    /// - Sets `diff` to `nil`, discarding any computed comparison between documents.
    /// - Sets `errorMessage` to `nil`, clearing any prior error messages.
    ///
    /// Use this to start a fresh comparison workflow, for example when the user wants to load new files.
    /// Intended to be called on the main actor within SwiftUI-driven flows so that UI updates occur safely.
    func reset() {
            oldDocument = nil
            newDocument = nil
            diff = nil
            errorMessage = nil
        }
}

