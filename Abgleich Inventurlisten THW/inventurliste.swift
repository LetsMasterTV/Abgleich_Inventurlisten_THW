//
//  ViewModel.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import Foundation
import CoreXLSX
import Combine


class Inventurliste {
    
    @Published var Inventurliste: [Bestandsobjekt] = []
    
    init(Pfad_Inventurliste: String) {
        guard let file = XLSXFile(filepath: Pfad_Inventurliste) else {
            print("XLSX file_alte Liste at \(Pfad_Inventurliste) is corrupted or does not exist")
            return
        }
        
        do {
            let sharedStrings:SharedStrings? = try file.parseSharedStrings()
            for wbk in try file.parseWorkbooks() {
                for (_, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                    let worksheet = try file.parseWorksheet(at: path)
                        self.Inventurliste = try read(in: worksheet, shared: sharedStrings)
                }
            }
        } catch {
            print("Fehler beim Laden der Daten in die Inventurliste \(error)")
        }
    }
    
    private func read(in worksheet: Worksheet, shared: SharedStrings? = nil) throws -> [Bestandsobjekt] {
        var tmp: [Bestandsobjekt] = []
        for row in worksheet.data?.rows ?? [] {
            
            var Eintraege: [String:String] = ["A": "", "B": "","C":"","D": "", "E": "","F":"","G":"","H":"","I":"","J":"", "K":""]
            for e in Eintraege.keys.sorted() {
                Eintraege[e] = try text(in: row, col: e, shared: shared).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let objekt = Bestandsobjekt(
                Ebene: Eintraege["A"]!,
                Art: Eintraege["B"]!,
                STAN_soll: Eintraege["C"]!,
                Menge_ist: Eintraege["D"]!,
                THWin_Bestand: Eintraege["E"]!,
                Fahrzeug_Bestand: Eintraege["F"]!,
                Beschreibung: Eintraege["G"]!,
                Sachnummer: Eintraege["H"]!,
                Inventarnummer: Eintraege["I"]!,
                Geraetenummer: Eintraege["J"]!,
                Status: Eintraege["K"]!
            )
            tmp.append(objekt)
        }
        return tmp
    }
    
    private func text(in row: Row, col: String, shared: SharedStrings? = nil) throws -> String  {
        guard let cell = row.cells.first(where: { $0.reference.column.value == col }) else { return "" }
        return cell.stringValue(shared!) ?? cell.inlineString?.text ?? cell.value ?? ""
    }
}

