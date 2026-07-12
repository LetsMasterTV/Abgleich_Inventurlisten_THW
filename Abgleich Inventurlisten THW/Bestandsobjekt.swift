//
//  File.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import Foundation

struct Bestandsobjekt: Hashable {
    
    let rowNumber: UInt
    let checked: Bool
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
    
}
