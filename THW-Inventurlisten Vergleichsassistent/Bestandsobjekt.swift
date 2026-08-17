//
//  File.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 07.07.2026.
//

import Foundation

/// A value type that represents an inventory item (Bestandsobjekt) used for comparing and tracking changes across data sources.
///
/// Conforms to:
/// - Identifiable: Each instance carries a unique, stable `id` created at initialization time.
/// - Equatable: Equality is defined by comparing all semantic fields (excluding `id`).
///
/// Parameter:
/// - id: A unique identifier (UUID) for UI identity and list diffing. Not considered in equality.
/// - Expected (not sorted) Table Headers in the XLSX Files
///     - `Ebene`
///     - `Art`
///     - `STAN_soll`
///     - `Menge_ist`
///     - `THWin_Bestand`
///     - `Fahrzeug_Bestand`
///     - `Beschreibung`
///     - `Sachnummer`
///     - `Inventarnummer`
///     - `Geraetenummer`
///     - `Status`
///
/// Computed properties:
/// - key: A composite key combining `Sachnummer` and `Inventarnummer`, useful for grouping or lookups.
///
/// Initialization:
/// - init?(from dict: [String: String]): Failable initializer that builds an instance from a dictionary of CSV/column values.
///   It trims surrounding whitespaces for all known keys. Returns `nil` if the dictionary is empty.
///   Expected keys (case-sensitive): "Ebene", "Art", "STAN soll", "Menge Ist", "THWin Bestand",
///   "Bestand Fahrzeug", "Beschreibung", "Sachnummer", "Inventarnummer", "Geraetenummer", "Status".
///
/// Equality:
/// - Two instances are equal if all semantic fields (excluding `id`) match exactly after initialization/trimming.
///
/// Change tracking:
/// - FieldChange: Nested type describing a single field change with a human-readable `label`,
///   the `oldValue`, and the `newValue`.
/// - fieldChanges(from:to:): Produces a list of `FieldChange` entries for all fields that differ
///   between two `Bestandsobjekt` values. Useful for diff views and audit logs.
    
    
    /// Returns a Boolean value indicating whether two Bestandsobjekt values are equal.
    ///
    /// Two instances are considered equal when all semantic fields match exactly,
    /// excluding the auto-generated `id`. The comparison includes:
    /// - `Ebene`
    /// - `Art`
    /// - `STAN_soll`
    /// - `Menge_ist`
    /// - `THWin_Bestand`
    /// - `Fahrzeug_Bestand`
    /// - `Beschreibung`
    /// - `Sachnummer`
    /// - `Inventarnummer`
    /// - `Geraetenummer`
    /// - `Status`
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side Bestandsobjekt to compare.
    ///   - rhs: The right-hand side Bestandsobjekt to compare.
    /// - Returns: `true` if all listed fields are equal; otherwise, `false`.
    /// - Note: The `id` property is intentionally ignored to allow semantic equality
    ///   independent of instance identity, which is useful for diffing and change tracking.

    struct Bestandsobjekt: Identifiable, Equatable, Hashable, Sendable{
        let id = UUID()
        let Zeile: Int   // Original-Zeilennummer aus der Excel-Datei – stabile Reihenfolge für den Hierarchie-Aufbau
        let Ebene: String
        let Ortseinheit: String
        let Art: String
        let Fremdbeschafft: String
        let Menge_STAN: String
        let Menge_ist: String
        let Verfuegbar: String
        let Beschreibung: String
        let Sachnummer: String
        let Inventarnummer: String
        let Geraetenummer: String
        let Status: String
     
        /// Stabiler Schlüssel zur Zuordnung zwischen zwei Dateien.
        /// Getrimmte Werte, da Excel-Zellen oft mit führenden/nachgestellten Leerzeichen befüllt sind.
        var key: String { Ebene + " " + Inventarnummer + " " + Sachnummer }
     
        // Manuelles Equatable: die zufällige UUID und die Zeilennummer dürfen NICHT mit verglichen werden –
        // eine Zeile kann in der neuen Datei an anderer Position stehen, ohne inhaltlich "geändert" zu sein.
        static func == (lhs: Bestandsobjekt, rhs: Bestandsobjekt) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(Ebene)
            hasher.combine(Ortseinheit)
            hasher.combine(Art)
            hasher.combine(Fremdbeschafft)
            hasher.combine(Menge_STAN)
            hasher.combine(Menge_ist)
            hasher.combine(Verfuegbar)
            hasher.combine(Beschreibung)
            hasher.combine(Sachnummer)
            hasher.combine(Inventarnummer)
            hasher.combine(Geraetenummer)
            hasher.combine(Status)
        }
     
        /// Baut ein Bestandsobjekt aus einem [Spaltenname: Wert]-Dictionary einer Excel-Zeile.
        /// Fehlende Werte (leere Zellen) werden als leerer String behandelt, NICHT als Abbruchgrund –
        /// sonst würde fast jede Zeile verworfen, sobald irgendein Feld leer ist.
        init?(from dict: [String: String], zeile: Int) {
            guard !dict.isEmpty else { return nil }
     
            self.Zeile = zeile
            self.Ebene = (dict["Ebene"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Ortseinheit = (dict["OE"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Art = (dict["Art"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Fremdbeschafft = (dict["FB"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Menge_STAN = (dict["Menge"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Menge_ist = (dict["Menge Ist"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Verfuegbar = (dict["Verfügbar"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Beschreibung = (dict["Ausstattung | Hersteller | Typ"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Sachnummer = (dict["Sachnummer"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Inventarnummer = (dict["Inventar Nr"] ?? "").trimmingCharacters(in: .whitespaces)
            self.Geraetenummer = (dict["Gerätenr."] ?? "").trimmingCharacters(in: .whitespaces)
            self.Status = (dict["Status"] ?? "").trimmingCharacters(in: .whitespaces)
        }
    }

/// A value type that represents an inventory item (Bestandsobjekt) used for importing,
/// comparing, and tracking changes across data sources (e.g., XLSX/CSV).
///
/// Purpose:
/// - Encapsulates all relevant fields of a THW inventory record.
/// - Provides semantic equality (ignores `id`) for diffing and change detection.
/// - Supplies utilities to compute human‑readable field changes.
///
/// Identity:
/// - Conforms to `Identifiable` with a stable `id` (UUID) generated at initialization time.
/// - The `id` is not part of semantic equality and is intended for UI identity and list diffing.
///
/// Equality:
/// - Conforms to `Equatable`.
/// - Two instances are equal if and only if all semantic fields match exactly:
///   `Ebene`, `Art`, `STAN_soll`, `Menge_ist`, `THWin_Bestand`, `Fahrzeug_Bestand`,
///   `Beschreibung`, `Sachnummer`, `Inventarnummer`, `Geraetenummer`, `Status`.
/// - The `id` is intentionally ignored during equality checks.
///
/// Fields:
/// - Ebene: The organizational or structural level of the item.
/// - Art: The type/category of the item.
/// - STAN_soll: Target/authorized quantity according to STAN.
/// - Menge_ist: Actual counted quantity.
/// - THWin_Bestand: Quantity recorded in THWin.
/// - Fahrzeug_Bestand: Quantity present on vehicles.
/// - Beschreibung: Human‑readable description of the item.
/// - Sachnummer: Catalog/article number; often used for grouping or matching.
/// - Inventarnummer: Inventory number; often unique per physical asset.
/// - Geraetenummer: Device number or equipment identifier.
/// - Status: Current status or condition of the item.
///
/// Derived Values:
/// - key: Composite lookup key combining `Sachnummer` and `Inventarnummer`.
///
/// Initialization:
/// - init?(from dict: [String: String])
///   - Failable initializer that populates all fields from a dictionary (e.g., a parsed CSV/XLSX row).
///   - Trims surrounding whitespaces for all recognized keys.
///   - Returns `nil` if the provided dictionary is empty.
///   - Expected (case‑sensitive) keys:
///     - "Ebene"
///     - "Art"
///     - "STAN soll"
///     - "Menge Ist"
///     - "THWin Bestand"
///     - "Bestand Fahrzeug"
///     - "Beschreibung"
///     - "Sachnummer"
///     - "Inventarnummer"
///     - "Geraetenummer"
///     - "Status"
///
/// Change Tracking:
/// - Nested type `FieldChange` describes a single differing field with:
///   - `label`: Human‑readable field name.
///   - `oldValue`: Value in the source (old) record.
///   - `newValue`: Value in the target (new) record.
/// - `fieldChanges(from:to:)` computes a list of `FieldChange` entries for all fields that differ
///   between two `Bestandsobjekt` instances, enabling detailed diff views and audit logs.
///
/// Usage Notes:
/// - Use semantic equality (==) to determine whether two records represent the same data,
///   regardless of their `id`.
/// - Use `key` when a compact, human‑readable grouping or dictionary key is needed.
/// - When importing from spreadsheets, ensure headers match the expected keys exactly (including case and spaces).
extension Bestandsobjekt {
    struct FieldChange: Identifiable {
        let id = UUID()
        let label: String
        let oldValue: String
        let newValue: String
    }

    /// Computes a list of human‑readable field differences between two Bestandsobjekt values.
    ///
    /// This helper compares each semantic field of the provided records (excluding `id`)
    /// and returns an array of `FieldChange` entries for every field whose value has changed.
    /// Each `FieldChange` contains a `label` (localized/CSV header name), the `oldValue` from
    /// the source record, and the `newValue` from the target record.
    ///
    /// Fields compared (in order):
    /// - "Ebene"
    /// - "Art"
    /// - "STAN soll"
    /// - "Menge Ist"
    /// - "THWin Bestand"
    /// - "Bestand Fahrzeug"
    /// - "Beschreibung"
    /// - "Sachnummer"
    /// - "Inventarnummer"
    /// - "Gerätenummer"
    /// - "Status"
    ///
    /// - Parameters:
    ///   - old: The source (baseline) Bestandsobjekt to compare from.
    ///   - new: The target Bestandsobjekt to compare to.
    /// - Returns: An array of `FieldChange` entries for all differing fields. The array is empty if no differences are found.
    /// - Note: String comparisons are exact (case‑sensitive) and performed after any trimming that occurred during initialization.
    /// - Use‑case: Ideal for building diff views, audit logs, or change summaries when importing or reconciling inventory data.
    static func fieldChanges(from old: Bestandsobjekt, to new: Bestandsobjekt) -> [FieldChange] {
        var changes: [FieldChange] = []

        func compare(_ label: String, _ oldValue: String, _ newValue: String) {
            if oldValue != newValue {
                changes.append(FieldChange(label: label, oldValue: oldValue, newValue: newValue))
            }
        }

        compare("Ebene", old.Ebene, new.Ebene)
        compare("Ortseinheit", old.Ortseinheit, new.Ortseinheit)
        compare("Art", old.Art, new.Art)
        compare("Fremdbeschafft", old.Fremdbeschafft, new.Fremdbeschafft)
        compare("Menge", old.Menge_STAN, new.Menge_STAN)
        compare("Menge Ist", old.Menge_ist, new.Menge_ist)
        compare("Verfügbar", old.Verfuegbar, new.Verfuegbar)
        compare("Ausstattung | Hersteller | Typ", old.Beschreibung, new.Beschreibung)
        compare("Sachnummer", old.Sachnummer, new.Sachnummer)
        compare("Inventarnummer", old.Inventarnummer, new.Inventarnummer)
        compare("Gerätenummer.", old.Geraetenummer, new.Geraetenummer)
        compare("Status", old.Status, new.Status)

        return changes
    }
}
