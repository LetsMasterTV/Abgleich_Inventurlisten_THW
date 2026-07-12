//
//  File.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import Foundation

struct Bestandsobjekt: Identifiable, Equatable {
    
    let id = UUID()
    let Ebene: String
    let Art: String
    let STAN_soll: String
    let Menge_ist: String
    let THWin_Bestand: String
    let Fahrzeug_Bestand: String
    let Beschreibung: String
    let Sachnummer: String
    let Inventarnummer: String
    let Geraetenummer: String
    let Status: String
    
    var key: String {Sachnummer + " " + Inventarnummer}
    
    
    static func == (lhs: Bestandsobjekt, rhs: Bestandsobjekt) -> Bool {
        lhs.Ebene == rhs.Ebene &&
        lhs.Art == rhs.Art &&
        lhs.STAN_soll == rhs.STAN_soll &&
        lhs.Menge_ist == rhs.Menge_ist &&
        lhs.THWin_Bestand == rhs.THWin_Bestand &&
        lhs.Fahrzeug_Bestand == rhs.Fahrzeug_Bestand &&
        lhs.Beschreibung == rhs.Beschreibung &&
        lhs.Sachnummer == rhs.Sachnummer &&
        lhs.Inventarnummer == rhs.Inventarnummer &&
        lhs.Geraetenummer == rhs.Geraetenummer &&
        lhs.Status == rhs.Status
    }
    
    init?(from dict: [String: String]) {
        guard !dict.isEmpty else { return nil }
        
        self.Ebene = (dict["Ebene"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Art = (dict["Art"] ?? "").trimmingCharacters(in: .whitespaces)
        self.STAN_soll = (dict["STAN soll"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Menge_ist = (dict["Menge Ist"] ?? "").trimmingCharacters(in: .whitespaces)
        self.THWin_Bestand = (dict["THWin Bestand"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Fahrzeug_Bestand = (dict["Bestand Fahrzeug"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Beschreibung = (dict["Beschreibung"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Sachnummer = (dict["Sachnummer"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Inventarnummer = (dict["Inventarnummer"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Geraetenummer = (dict["Geraetenummer"] ?? "").trimmingCharacters(in: .whitespaces)
        self.Status = (dict["Status"] ?? "").trimmingCharacters(in: .whitespaces)
    }
}
