//
//  XLSXViewModel.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//
import SwiftUI
import Foundation

@Observable
class XLSXViewModel {
    var oldDocument: Inventurliste?
    var newDocument: Inventurliste?
    var diff: XLSXDiff?
    var errorMessage: String?
 
    func load(data: Data, as slot: DocumentSlot) {
        errorMessage = nil
        print("▶️ load() aufgerufen für Slot: \(slot), Datengröße: \(data.count) Bytes")
        do {
            let document = try Inventurliste(data: data)
            print("✅ Geparst: Sheet, \(document.inventurliste.count) Produkte")
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
 
    private func recomputeDiffIfPossible() {
        guard let oldDocument, let newDocument else { return }
        diff = oldDocument.diff(against: newDocument)
    }
    
    func reset() {
            oldDocument = nil
            newDocument = nil
            diff = nil
            errorMessage = nil
        }
}

