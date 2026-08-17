//
//  ModifiedBestandsobjektView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//
import SwiftUI

/// A SwiftUI view that displays a comparison of two Bestandsobjekt instances, highlighting modified fields.
///
/// ModifiedBestandsobjektRow renders a concise, human-readable diff between an "old"
/// and a "new" Bestandsobjekt. It emphasizes changed values with color and typography:
/// - The title (Beschreibung) shows the new value in green and, if changed, the old value
///   below it with a red strikethrough.
/// - A badge-like caption on the trailing side indicates the total number of modified fields.
/// - Below the header, a grid lists key fields. For each changed field, the old value is
///   shown in red with a strikethrough followed by the new value in green; unchanged fields
///   are displayed normally.
///
/// Behavior and layout details:
/// - The view computes changes via Bestandsobjekt.fieldChanges(from:to:) and uses the label
///   string to match fields.
/// - If the "Beschreibung" field has changed, the header renders the new description prominently
///   and shows the old description struck through; otherwise, it displays the current description
///   as a standard headline.
/// - The Sachnummer is shown as a secondary subheadline below the header.
/// - The grid presents the following fields (in two columns, flexible width): Ebene, Art,
///   STAN soll, Menge Ist, THWin Bestand, Bestand Fahrzeug, Inventarnummer, Gerätenummer, Status.
/// - Empty values are rendered as a dash (–) for clarity.
///
/// Styling conventions:
/// - New/updated values: green, semibold where emphasized.
/// - Old/replaced values: red with strikethrough.
/// - Labels: caption2, secondary foreground style.
/// - Change count: caption2, orange foreground style.
///
/// Requirements:
/// - Bestandsobjekt must provide a static diffing API:
///   Bestandsobjekt.fieldChanges(from:to:) -> [Bestandsobjekt.FieldChange],
///   where FieldChange includes at least `label`, `oldValue`, and `newValue`.
///
/// Use cases:
/// - Review and confirm updates before persisting changes.
/// - Present a summary of modifications in audit or history views.
/// - Display merge/conflict resolutions by surfacing what would change.
///
/// Accessibility:
/// - Color is used to indicate change; consider complementing with accessibility labels
///   or traits if used in contexts where color alone is insufficient.
///
/// - Parameters:
///   - old: The original Bestandsobjekt used as the baseline for comparison.
///   - new: The updated Bestandsobjekt whose values are compared against `old`.
struct ModifiedBestandsobjektRow: View {
    let old: Bestandsobjekt
    let new: Bestandsobjekt
    var hideDescription: Bool = false
    var hideProperties: Bool = false
 
    private var changes: [Bestandsobjekt.FieldChange] {
        Bestandsobjekt.fieldChanges(from: old, to: new)
    }
 
    /// Schnellzugriff: ist ein bestimmtes Feld (per Label) geändert? Falls ja, liefert es den alten Wert.
    private func change(for label: String) -> Bestandsobjekt.FieldChange? {
        changes.first { $0.label == label }
    }
 
    var body: some View {
        let changes = Bestandsobjekt.fieldChanges(from: old, to: new)

            let changesByLabel = Dictionary(
                uniqueKeysWithValues: changes.map {
                    ($0.label, $0)
                }
            )

            return VStack(alignment: .leading, spacing: 8) {
            if !hideDescription {
                if let beschreibungChange = changesByLabel["Beschreibung"] {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(beschreibungChange.newValue.isEmpty ? "(ohne Beschreibung)" : beschreibungChange.newValue)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                                .lineLimit(1)
                            Spacer()
                            Text("\(changes.count) Feld\(changes.count == 1 ? "" : "er") geändert")
                                .font(.caption)
                                .fontWeight(.medium)
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
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(changes.count) Feld\(changes.count == 1 ? "" : "er") geändert")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }
                }
            }
            if (!hideProperties) {
            // Alle Felder wie bei BestandsobjektRow, aber geänderte Felder zeigen Alt/Neu
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow(alignment: .top) {
                        fieldCell("Ebene", new.Ebene, changesByLabel: changesByLabel)
                        fieldCell("Ortseinheit", new.Ortseinheit, changesByLabel: changesByLabel)
                        fieldCell("Art", new.Art, changesByLabel: changesByLabel)
                        fieldCell("Fremdbeschafft", new.Fremdbeschafft, changesByLabel: changesByLabel)
                        fieldCell("Menge STAN", new.Menge_STAN, changesByLabel: changesByLabel)
                        fieldCell("Menge Ist", new.Menge_ist, changesByLabel: changesByLabel)
                        fieldCell("Verfügbar", new.Verfuegbar, changesByLabel: changesByLabel)
                        fieldCell("Ausstattung | Hersteller | Typ", new.Beschreibung, changesByLabel: changesByLabel)
                        fieldCell("Sachnummer", new.Sachnummer, changesByLabel: changesByLabel)
                        fieldCell("Inventarnummer", new.Inventarnummer, changesByLabel: changesByLabel)
                        fieldCell("Gerätenummer", new.Geraetenummer, changesByLabel: changesByLabel)
                        fieldCell("Status", new.Status, changesByLabel: changesByLabel)
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .fixedSize(horizontal: true, vertical: false)
    }
 
    @ViewBuilder
    private func fieldCell(
        _ label: String,
        _ newValue: String,
        changesByLabel: [String: Bestandsobjekt.FieldChange]
    ) -> some View {
        if let change = changesByLabel[label] {
            // Geändertes Feld: alter Wert durchgestrichen/rot, neuer Wert grün darunter
            VStack(alignment: .center, spacing: 8) {
                Text("\(label):")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(change.newValue.isEmpty ? "–" : change.newValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                Text(change.oldValue.isEmpty ? "–" : "\(change.oldValue)")
                    .font(.headline)
                    .strikethrough(true, color: .red)
                    .foregroundStyle(.red)
            }
        } else {
            // Unverändertes Feld: normale Anzeige wie in BestandsobjektRow
            VStack(alignment: .center, spacing: 8) {
                Text("\(label):")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(newValue.isEmpty ? "–" : newValue)
                    .font(.headline)
                    .fontWeight(.medium)
            }
        }
    }
}
