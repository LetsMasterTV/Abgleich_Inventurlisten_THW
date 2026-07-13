//
//  ModifiedBestandsobjektView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//
import SwiftUI

struct ModifiedBestandsobjektRow: View {
    let old: Bestandsobjekt
    let new: Bestandsobjekt
 
    private var changes: [Bestandsobjekt.FieldChange] {
        Bestandsobjekt.fieldChanges(from: old, to: new)
    }
 
    /// Schnellzugriff: ist ein bestimmtes Feld (per Label) geändert? Falls ja, liefert es den alten Wert.
    private func change(for label: String) -> Bestandsobjekt.FieldChange? {
        changes.first { $0.label == label }
    }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
                if let beschreibungChange = change(for: "Beschreibung") {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(beschreibungChange.newValue.isEmpty ? "(ohne Beschreibung)" : beschreibungChange.newValue)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(changes.count) Feld\(changes.count == 1 ? "" : "er") geändert")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Text(beschreibungChange.oldValue.isEmpty ? "(ohne Beschreibung)" : beschreibungChange.oldValue)
                                    .font(.subheadline)
                                    .strikethrough(true, color: .red)
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                        } else {
                            HStack {
                                Text(new.Beschreibung)
                                    .font(.headline)
                                Spacer()
                                Text("\(changes.count) Feld\(changes.count == 1 ? "" : "er") geändert")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

            
            Text(new.Sachnummer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
 
            // Alle Felder wie bei BestandsobjektRow, aber geänderte Felder zeigen Alt/Neu
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                fieldCell("Ebene", new.Ebene)
                fieldCell("Art", new.Art)
                fieldCell("STAN soll", new.STAN_soll)
                fieldCell("Menge Ist", new.Menge_ist)
                fieldCell("THWin Bestand", new.THWin_Bestand)
                fieldCell("Bestand Fahrzeug", new.Fahrzeug_Bestand)
                fieldCell("Inventarnummer", new.Inventarnummer)
                fieldCell("Gerätenummer", new.Geraetenummer)
                fieldCell("Status", new.Status)
            }
        }
        .padding(.vertical, 4)
    }
 
    @ViewBuilder
    private func fieldCell(_ label: String, _ newValue: String) -> some View {
        if let change = change(for: label) {
            // Geändertes Feld: alter Wert durchgestrichen/rot, neuer Wert grün darunter
            HStack(spacing: 4,) {
                Text("\(label):")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(change.oldValue.isEmpty ? "–" : "\(change.oldValue)")
                    .font(.caption)
                    .strikethrough(true, color: .red)
                    .foregroundStyle(.red)
                Text(change.newValue.isEmpty ? "–" : change.newValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
        } else {
            // Unverändertes Feld: normale Anzeige wie in BestandsobjektRow
            HStack(spacing: 4) {
                Text("\(label):")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(newValue.isEmpty ? "–" : newValue)
                    .font(.caption)
            }
        }
    }
}
