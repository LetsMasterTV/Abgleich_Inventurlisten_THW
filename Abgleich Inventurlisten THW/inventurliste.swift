//
//  ViewModel.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import Foundation
import CoreXLSX
import Combine


struct Inventurliste {
        let inventurliste: [Bestandsobjekt]
     
        enum ParseError: Error, LocalizedError {
            case invalidFile
            case noSheetFound
     
            var errorDescription: String? {
                switch self {
                case .invalidFile: return "Konnte xlsx-Datei nicht öffnen"
                case .noSheetFound: return "Kein Sheet in der Datei gefunden"
                }
            }
        }
    
    init(data: Data) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xlsx")
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
            
        try data.write(to: tempURL)
        
        guard let file = XLSXFile(filepath: tempURL.path) else {
            throw ParseError.invalidFile
        }
        
        do {
            var tmp: [Bestandsobjekt] = []
            guard let sharedStrings = try file.parseSharedStrings() else {
                   print("⚠️ Keine SharedStrings in der Datei gefunden")
                   self.inventurliste = []
                   return
               }// ✅ speichern, nicht verwerfen

            for wbk in try file.parseWorkbooks() {
                for (sheetName, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                    let worksheet = try file.parseWorksheet(at: path)
                    let allrows = worksheet.data?.rows ?? []
                    
                    guard let headerows = allrows.first else { continue }

                    let headers = Self.extractHeaders(from: headerows, sharedStrings: sharedStrings)
                    print("📋 Header in '\(sheetName ?? "?")': \(headers)")

                    for row in allrows.dropFirst() {
                        var dict: [String: String] = [:]
                        for cell in row.cells {
                            guard let idx = Self.columnIndex(fromLetters: cell.reference.column.value),
                                  idx < headers.count else { continue }
                            let header = headers[idx]
                            guard !header.isEmpty else { continue }

                            // ✅ Zellwert korrekt auflösen: erst Shared String versuchen, dann Inline-Text, dann Rohwert
                            let resolvedValue = cell.stringValue(sharedStrings)
                                ?? cell.inlineString?.text
                                ?? cell.value
                                ?? ""
                            dict[header] = resolvedValue
                        }
                       
                        if let objekt = Bestandsobjekt(from: dict) {
                            tmp.append(objekt)
                        }
                    }
                }
            }
            self.inventurliste = tmp
        } catch {
            print("Fehler beim Laden der Daten in die Inventurliste \(error)")
            self.inventurliste = []
        }
        
    }
    
    
    private static func columnIndex(fromLetters letters: String) -> Int? {
        var result = 0
        for char in letters.uppercased() {
            guard let ascii = char.asciiValue, ascii >= 65, ascii <= 90 else { return nil }
            result = result * 26 + Int(ascii - 65 + 1)
        }
        return result - 1
    }
 
    
    
    private static func extractHeaders(from row: Row, sharedStrings: SharedStrings) -> [String] {
        let maxIndex = row.cells
            .compactMap { columnIndex(fromLetters: $0.reference.column.value) }
            .max() ?? 0

        var headers = Array(repeating: "", count: maxIndex + 1)
        for cell in row.cells {
            if let idx = columnIndex(fromLetters: cell.reference.column.value) {
                headers[idx] = cell.stringValue(sharedStrings)
                    ?? cell.inlineString?.text
                    ?? cell.value
                    ?? ""
            }
        }
        return headers
    }
 
    
    private static func read(in worksheet: Worksheet, shared: SharedStrings? = nil) throws {
        
    }
}
    
extension Inventurliste {
    func diff(against other: Inventurliste) -> XLSXDiff {
        let (oldByKey, oldDuplicates) = Self.buildDictionary(from: self.inventurliste)
        let (newByKey, newDuplicates) = Self.buildDictionary(from: other.inventurliste)

        var added: [Bestandsobjekt] = []
        var modified: [(alt: Bestandsobjekt, new: Bestandsobjekt, changedFields: [String])] = []
        var unchanged: [Bestandsobjekt] = []

        for (key, newProduct) in newByKey {
            if let oldProduct = oldByKey[key] {
                if oldProduct == newProduct {
                    unchanged.append(newProduct)
                } else {
                    modified.append((alt: oldProduct, new: newProduct,
                                      changedFields: Self.changedFields(old: oldProduct, new: newProduct)))
                }
            } else {
                added.append(newProduct)
            }
        }

        var removed: [Bestandsobjekt] = []
        for (key, oldProduct) in oldByKey where newByKey[key] == nil {
            removed.append(oldProduct)
        }
        
        return XLSXDiff(added: added, removed: removed, modified: modified, unchanged: unchanged)
    }

    private static func buildDictionary(from items: [Bestandsobjekt]) -> (dict: [String: Bestandsobjekt], duplicates: Set<String>) {
        var dict: [String: Bestandsobjekt] = [:]
        var duplicates: Set<String> = []
        var seenCounts: [String: Int] = [:]

        for item in items {
            let baseKey = item.key
            let occurrence = (seenCounts[baseKey] ?? 0) + 1
            seenCounts[baseKey] = occurrence

            // Erstes Vorkommen behält den normalen Key, ab dem zweiten wird ein Suffix angehängt
            let uniqueKey = occurrence == 1 ? baseKey : "\(baseKey) #\(occurrence)"

            if occurrence > 1 {
                duplicates.insert(baseKey)
            }

            dict[uniqueKey] = item
        }
        return (dict, duplicates)
    }

    private static func changedFields(old: Bestandsobjekt, new: Bestandsobjekt) -> [String] {
        var fields: [String] = []
        if old.Ebene != new.Ebene { fields.append("Ebene") }
        if old.Art != new.Art { fields.append("Art") }
        if old.STAN_soll != new.STAN_soll { fields.append("STAN soll") }
        if old.Menge_ist != new.Menge_ist { fields.append("Menge ist") }
        if old.THWin_Bestand != new.THWin_Bestand { fields.append("THWin_Bestand") }
        if old.Fahrzeug_Bestand != new.Fahrzeug_Bestand { fields.append("Fahrzeug Bestand") }
        if old.Beschreibung != new.Beschreibung { fields.append("Beschreibung") }
        if old.Sachnummer != new.Sachnummer { fields.append("Sachnummer") }
        if old.Inventarnummer != new.Inventarnummer { fields.append("Inventarnummer") }
        if old.Geraetenummer != new.Geraetenummer { fields.append("Gerätenummer") }
        if old.Status != new.Status { fields.append("Status") }
        return fields
    }
}
