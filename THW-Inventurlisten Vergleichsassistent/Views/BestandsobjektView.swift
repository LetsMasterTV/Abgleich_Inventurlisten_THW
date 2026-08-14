//
//  BestandsobjektView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

/// A SwiftUI view that presents a single inventory item (Bestandsobjekt) in a compact, readable row layout.
///
/// The row displays:
/// - A headline with the item's description (or a placeholder if missing),
/// - A capsule-styled status badge aligned to the trailing edge,
/// - The item's "Sachnummer" as a secondary subheadline,
/// - A two-column grid of labeled detail fields including:
///   - Ebene
///   - Art
///   - STAN soll
///   - Menge Ist
///   - THWin Bestand
///   - Bestand Fahrzeug
///   - Inventarnummer
///   - Gerätenummer
///
/// Empty string values in detail fields are rendered as an en dash (–) to indicate absence of data.
///
/// Layout and styling notes:
/// - Primary information (description) uses `.headline`.
/// - Status uses `.caption` within a light gray capsule background.
/// - "Sachnummer" uses `.subheadline` with secondary foreground style.
/// - Detail fields use `.caption` (values) and `.caption2` (labels) with secondary style for labels.
/// - The detail grid uses two flexible columns to adapt to available width.
///
/// Dependencies:
/// - Expects a `Bestandsobjekt` model with the following `String` properties:
///   `Beschreibung`, `Status`, `Sachnummer`, `Ebene`, `Art`, `STAN_soll`,
///   `Menge_ist`, `THWin_Bestand`, `Fahrzeug_Bestand`, `Inventarnummer`, `Geraetenummer`.
///
/// Accessibility:
/// - Uses textual labels and values suitable for VoiceOver.
/// - Consider adding accessibility identifiers if used in UI tests.
///
/// Example usage:
/// ```swift
/// BestandsobjektRow(objekt: bestandsobjekt)
/// ```
///
/// - SeeAlso: `Bestandsobjekt`
struct BestandsobjektRow: View {
    let objekt: Bestandsobjekt
    var hideDescription: Bool = false
    var hideProperties: Bool = false
 
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hideDescription {
                HStack {
                    Text(objekt.Beschreibung.isEmpty ? "(ohne Beschreibung)" : objekt.Beschreibung)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
 
            if (!hideProperties) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow(alignment: .top) {
                        labeledField("Ebene", objekt.Ebene)
                        labeledField("Ortseinheit", objekt.Ortseinheit)
                        labeledField("Art", objekt.Art)
                        labeledField("Fremdbeschafft", objekt.Fremdbeschaft)
                        labeledField("STAN soll", objekt.Menge_STAN)
                        labeledField("Menge Ist", objekt.Menge_ist)
                        labeledField("THWin Bestand", objekt.Verfuegbar)
                        labeledField("Ausstattung | Hersteller | Typ", objekt.Beschreibung)
                        labeledField("Sachnummer", objekt.Sachnummer)
                        labeledField("Inventarnummer", objekt.Inventarnummer)
                        labeledField("Gerätenummer", objekt.Geraetenummer)
                        labeledField("Status", objekt.Status)
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .fixedSize(horizontal: true, vertical: false)
    }
 
    @ViewBuilder
    private func labeledField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text("\(label):")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "–" : value)
                .font(.headline)
                .fontWeight(.medium)
        }
    }
}
