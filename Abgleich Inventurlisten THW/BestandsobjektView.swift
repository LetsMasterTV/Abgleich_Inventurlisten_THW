//
//  BestandsobjektView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

struct BestandsobjektRow: View {
    let objekt: Bestandsobjekt
    var highlightedFields: Set<String> = []   // z.B. bei "modified", welche Felder sich geändert haben

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(objekt.Beschreibung.isEmpty ? "(ohne Bescheibung)" : objekt.Beschreibung)
                    .font(.headline)
                Spacer()
                Text(objekt.Status)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(objekt.Sachnummer)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Kompaktes Gitter mit allen restlichen Feldern
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                field("Ebene", objekt.Ebene)
                field("Art", objekt.Art)
                field("STAN soll", objekt.STAN_soll)
                field("Menge Ist", objekt.Menge_ist)
                field("THWin Bestand", objekt.THWin_Bestand)
                field("Bestand Fahrzeug", objekt.Fahrzeug_Bestand)
                field("Inventarnummer", objekt.Inventarnummer)
                field("Gerätenummer", objekt.Geraetenummer)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func field(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "–" : value)
                .font(.caption)
                .fontWeight(highlightedFields.contains(label) ? .bold : .regular)
                .foregroundStyle(highlightedFields.contains(label) ? .orange : .primary)
        }
    }
}
