//
//  Inventurliste.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import Foundation
import CoreXLSX
import Combine


/// A value type that represents an inventory list parsed from an .xlsx spreadsheet.
///
/// Inventurliste is responsible for:
/// - Parsing an Excel (.xlsx) file from raw Data into a collection of Bestandsobjekt entries
/// - Resolving cell values using CoreXLSX (shared strings, inline strings, or raw values)
/// - Extracting header mappings from the first row of each worksheet to build row dictionaries
/// - Providing a diff operation to compare two inventory lists and classify changes
///
/// Parsing behavior:
/// - The initializer writes the provided Data to a temporary .xlsx file and uses CoreXLSX to read it.
/// - It iterates through all workbooks and worksheets, reads the first row as headers, and then builds
///   a dictionary per subsequent row using the column headers as keys.
/// - Cell values are resolved in the following order: shared string, inline string, raw value, or "" if unavailable.
/// - Rows that can be converted to Bestandsobjekt using Bestandsobjekt(from:) are appended to the list.
/// - If SharedStrings are missing, the list will be empty and a warning is logged.
/// - Temporary files are cleaned up automatically.
///
/// Error handling:
/// - Throws ParseError.invalidFile if the .xlsx file cannot be opened.
/// - Throws ParseError.noSheetFound if no sheet is found in the file (not currently thrown in the implementation).
///
/// Comparison:
/// - The diff(against:) method compares two Inventurliste instances and returns an XLSXDiff:
///   - added: items present only in the new list
///   - removed: items present only in the old list
///   - modified: items present in both lists but with differing content
///   - unchanged: items identical across both lists
/// - Duplicate keys are handled by buildDictionary(from:) which generates unique keys using a “#n” suffix
///   for subsequent occurrences while tracking duplicates.
///
/// Dependencies:
/// - CoreXLSX for reading .xlsx files
/// - Bestandsobjekt for representing parsed rows
/// - XLSXDiff for diff results
///
/// Notes:
/// - Column addressing (e.g., “A”, “B”, …, “AA”) is translated to zero-based indices.
/// - Header extraction pads missing columns with empty strings to maintain correct indexing.
/// - This type is a lightweight wrapper around an immutable array; parsing happens only during initialization.
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
    /// initializes a 'Inventurliste' from a .xlsx file reading all rows over all Worksheets
    ///
    /// - Parameters:
    ///    - Data: Die Hochgeladene XLSX Datei
    init(data: Data) throws {
        // Erstellen einer Temporären URL im Arbeitsspeicher'
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xlsx")
        
        // Schiefgelaufener Kopier versuch bereinigen
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
               }

            for wbk in try file.parseWorkbooks() {
                for (_, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                    let worksheet = try file.parseWorksheet(at: path)
                    let allrows = worksheet.data?.rows ?? []
                    // Header auslesen
                    guard let headerows = allrows.first else { continue }
                    
                    let headers = Self.extractHeaders(from: headerows, sharedStrings: sharedStrings)
                    var rowCounter = 0
                    
                    for row in allrows.dropFirst() {
                        rowCounter += 1
                        var dict: [String: String] = [:]
                        for cell in row.cells {
                            guard let idx = Self.columnIndex(fromLetters: cell.reference.column.value),
                                  idx < headers.count else { continue }
                            let header = headers[idx]
                            guard !header.isEmpty else { continue }
                            
                            // Zellwert korrekt auflösen: Shared String zuerst, dann Inline-Text, dann Rohwert
                            let resolvedValue = cell.stringValue(sharedStrings)
                            ?? cell.inlineString?.text
                            ?? cell.value
                            ?? ""
                            dict[header] = resolvedValue
                        }
                        
                        if let objekt = Bestandsobjekt(from: dict, zeile: rowCounter) {
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
    
    
    /// Converts an Excel-style column label (e.g., "A", "Z", "AA", "BC") into a zero-based integer index.
    ///
    /// Excel columns are labeled using a base-26 alphabetic system where:
    /// - "A" corresponds to index 0
    /// - "B" corresponds to index 1
    /// - ...
    /// - "Z" corresponds to index 25
    /// - "AA" corresponds to index 26
    /// - "AB" corresponds to index 27, and so on.
    ///
    /// The conversion treats the string as a base-26 number with letters 'A' to 'Z' mapping to 1–26,
    /// and then subtracts 1 from the final result to produce a zero-based index.
    ///
    /// Validation:
    /// - Returns `nil` if the input contains characters outside A–Z/a–z.
    ///
    /// - Parameter letters: The Excel column label to convert. Case-insensitive.
    /// - Returns: The zero-based column index if the label is valid; otherwise, `nil`.
    private static func columnIndex(fromLetters letters: String) -> Int? {
        var result = 0
        for char in letters.uppercased() {
            guard let ascii = char.asciiValue, ascii >= 65, ascii <= 90 else { return nil }
            result = result * 26 + Int(ascii - 65 + 1)
        }
        return result - 1
    }
 
    
    
    /// Extracts the header titles from the first row of a worksheet, preserving column positions.
    ///
    /// This method interprets the provided row as the header row of a worksheet and returns an array
    /// of header strings aligned by column index. Column references (e.g., A, B, AA) are translated
    /// into zero-based indices to correctly position each header in the resulting array. Missing
    /// or skipped columns are represented by empty strings to maintain proper alignment with the
    /// worksheet's column structure.
    ///
    /// Cell value resolution order:
    /// - Attempts to resolve a cell as a shared string using the provided `sharedStrings`.
    /// - Falls back to the cell's inline string content.
    /// - Falls back to the raw cell value.
    /// - Defaults to an empty string if no content is available.
    ///
    /// Notes:
    /// - Only cells with valid A–Z column references are considered.
    /// - The resulting array length is determined by the highest populated column index in the row,
    ///   ensuring the array is large enough to include all present headers.
    ///
    /// - Parameters:
    ///   - row: The worksheet row assumed to contain header cells.
    ///   - sharedStrings: The shared strings table used to resolve shared-string cell values.
    /// - Returns: An array of header titles, where each element corresponds to a column index. Empty
    ///            strings indicate columns without a header value or missing cells.
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
 }
    
    /// Computes a detailed difference between this inventory list and another, classifying items as added, removed, modified, or unchanged.
    ///
    /// This method compares two Inventurliste instances by building unique, occurrence-aware keys for each Bestandsobjekt
    /// (using `buildDictionary(from:)`). It then:
    /// - Marks items present only in the new list as `added`.
    /// - Marks items present only in the old list as `removed`.
    /// - Marks items present in both lists with identical content as `unchanged`.
    /// - Marks items present in both lists with differing content as `modified` (returned as pairs of old and new values).
    ///
    /// Handling of duplicates:
    /// - Keys are generated from each item's `Bestandsobjekt.key`.
    /// - Duplicate base keys are disambiguated by appending a " #n" suffix to subsequent occurrences (e.g., "ABC", "ABC #2").
    /// - This ensures all duplicates are preserved and compared positionally by their unique occurrence keys.
    ///
    /// Equality semantics:
    /// - Items are considered equal (and thus `unchanged`) if `Bestandsobjekt` conforms to `Equatable` and `==` returns true.
    /// - Otherwise, they are classified as `modified`.
    ///
    /// - Parameter other: The other Inventurliste to compare against (treated as the "new" list).
    /// - Returns: An `XLSXDiff` containing arrays of `added`, `removed`, `modified` (as `(alt:new:)` tuples), and `unchanged` items.
    /// - Note: The order within each result array reflects dictionary iteration order of the keyed collections and is not guaranteed to be stable.
 
    
    /// Builds a dictionary of Bestandsobjekt items keyed by a unique string while tracking duplicate base keys.
    ///
    /// This helper is used to prepare inventory items for comparison (e.g., diffing) by:
    /// - Creating a stable, unique key for every occurrence of an item based on its `Bestandsobjekt.key`.
    /// - Preserving all duplicates instead of overwriting them by appending an occurrence suffix " #n"
    ///   to the key starting with the second appearance (e.g., "ABC", "ABC #2", "ABC #3").
    /// - Recording which base keys appeared more than once.
    ///
    /// Behavior:
    /// - The first occurrence of a given `item.key` is stored under the plain key (e.g., "ABC").
    /// - Each subsequent occurrence of the same base key is stored under a suffixed key (e.g., "ABC #2").
    /// - The returned `duplicates` set contains the base keys that had 2 or more occurrences.
    ///
    /// - Parameter items: The list of Bestandsobjekt entries to index.
    /// - Returns: A tuple containing:
    ///   - dict: A dictionary mapping unique keys to their corresponding Bestandsobjekt.
    ///   - duplicates: A set of base keys that occurred more than once in the input.
extension Inventurliste {
    func diff(against other: Inventurliste) -> XLSXDiff {
        let parentsOld = Self.computeParents(for: self.inventurliste)
        let parentsNew = Self.computeParents(for: other.inventurliste)

        // Pfadsegment für ein einzelnes Element (mit Ebenen-Präfix) – wertet leere Ebenen als "0"
        func segment(for item: Bestandsobjekt) -> String {
            let ebene = item.Ebene.isEmpty ? "0" : (Int(item.Ebene) != nil ? item.Ebene : "0")
            return "[\(ebene)] \(item.key)"
        }

        func generierePfadListe(aus elementen: [Bestandsobjekt], parents: [UUID: Bestandsobjekt]) -> [PfadElement] {
            let pfade = Self.vollePfade(fuer: elementen, parents: parents, segment: segment)
            return elementen.map { item in
                PfadElement(vollstaendigerPfad: pfade[item.id] ?? segment(for: item), objekt: item)
            }
        }
        
        let altePfade = generierePfadListe(aus: self.inventurliste, parents: parentsOld)
        let neuePfade = generierePfadListe(aus: other.inventurliste, parents: parentsNew)

        func groupByFullPath(_ elements: [PfadElement]) -> [String: [Bestandsobjekt]] {
            var dict: [String: [Bestandsobjekt]] = [:]
            for el in elements {
                dict[el.vollstaendigerPfad, default: []].append(el.objekt)
            }
            for key in dict.keys {
                dict[key]?.sort { $0.Zeile < $1.Zeile }
            }
            return dict
        }

        let oldGroups = groupByFullPath(altePfade)
        let newGroups = groupByFullPath(neuePfade)

        var added: [Bestandsobjekt] = []
        var removed: [Bestandsobjekt] = []
        var modified: [(alt: Bestandsobjekt, new: Bestandsobjekt)] = []
        var unchanged: [Bestandsobjekt] = []

        var oldDuplicates = Set<String>()
        var newDuplicates = Set<String>()

        let allPaths = Set(oldGroups.keys).union(newGroups.keys)

        for pfad in allPaths {
            let olds = oldGroups[pfad] ?? []
            let news = newGroups[pfad] ?? []

            var matchedNewIndices = Set<Int>()
            var matchedOldIndices = Set<Int>()

            for (oldIdx, oldItem) in olds.enumerated() {
                for (newIdx, newItem) in news.enumerated() {
                    if !matchedNewIndices.contains(newIdx) && oldItem == newItem {
                        unchanged.append(newItem)
                        matchedOldIndices.insert(oldIdx)
                        matchedNewIndices.insert(newIdx)
                        break
                    }
                }
            }

            let remainingOlds = olds.enumerated().filter { !matchedOldIndices.contains($0.offset) }.map { $0.element }
            let remainingNews = news.enumerated().filter { !matchedNewIndices.contains($0.offset) }.map { $0.element }

            let pairCount = min(remainingOlds.count, remainingNews.count)

            for i in 0..<pairCount {
                modified.append((alt: remainingOlds[i], new: remainingNews[i]))
            }

            if remainingOlds.count > pairCount {
                removed.append(contentsOf: remainingOlds[pairCount...])
            }
            if remainingNews.count > pairCount {
                added.append(contentsOf: remainingNews[pairCount...])
            }

            if remainingOlds.count > 1 { oldDuplicates.insert(pfad) }
            if remainingNews.count > 1 { newDuplicates.insert(pfad) }
        }

        return XLSXDiff(
            added: added,
            removed: removed,
            modified: modified,
            unchanged: unchanged,
            duplicateKeysOld: oldDuplicates,
            duplicateKeysNew: newDuplicates
        )
    }
}



extension Inventurliste {
    /// Ermittelt für jedes Objekt in einer geordneten Liste (Original-Reihenfolge aus der Excel-Datei!)
    /// das nächstgelegene VORHERIGE Objekt mit niedrigerer Ebene – dessen direktes "Elternteil".
    static func computeParents(for items: [Bestandsobjekt]) -> [UUID: Bestandsobjekt] {
        var result: [UUID: Bestandsobjekt] = [:]
        var stack: [(level: Int, obj: Bestandsobjekt)] = []

        for item in items {
            let level = Int(item.Ebene) ?? 0
            while let last = stack.last, last.level >= level {
                stack.removeLast()
            }
            if let parent = stack.last {
                result[item.id] = parent.obj
            }
            stack.append((level, item))
        }
        return result
    }

    /// Berechnet für eine in Original-Zeilenreihenfolge vorliegende Liste die vollständigen Pfade
    /// (Wurzel → Element) in O(n), statt für jedes Element einzeln bis zur Wurzel hochzulaufen.
    /// `segment` bestimmt das Pfadsegment pro Element (Default: einfach der Key).
    /// Voraussetzung: Elternteile stehen in `items` vor ihren Kindern (Original-Zeilenreihenfolge).
    static func vollePfade(
        fuer items: [Bestandsobjekt],
        parents: [UUID: Bestandsobjekt],
        segment: (Bestandsobjekt) -> String = { $0.key }
    ) -> [UUID: String] {
        var cache: [UUID: String] = [:]
        cache.reserveCapacity(items.count)
        for item in items {
            let eigenesSegment = segment(item)
            if let parent = parents[item.id], let parentPath = cache[parent.id] {
                cache[item.id] = parentPath + "/" + eigenesSegment
            } else {
                cache[item.id] = eigenesSegment
            }
        }
        return cache
    }
}
