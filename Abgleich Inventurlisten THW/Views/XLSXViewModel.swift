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
  
    enum DocumentSlot { case old, new }
 
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
 
    /// Setzt den gesamten Zustand zurück auf den Ausgangswert
    func reset() {
        oldDocument = nil
        newDocument = nil
        diff = nil
        errorMessage = nil
    }
 
    private func recomputeDiffIfPossible() {
        guard let oldDocument, let newDocument else { return }
        diff = oldDocument.diff(against: newDocument)
    }
}


