//
//  BestandsobjektView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

struct BestandsobjektRow: View {
    let objekt: Bestandsobjekt
 
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(objekt.Beschreibung.isEmpty ? "(ohne Beschreibung)" : objekt.Beschreibung)
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
 
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 2) {
                labeledField("Ebene", objekt.Ebene)
                labeledField("Art", objekt.Art)
                labeledField("STAN soll", objekt.STAN_soll)
                labeledField("Menge Ist", objekt.Menge_ist)
                labeledField("THWin Bestand", objekt.THWin_Bestand)
                labeledField("Bestand Fahrzeug", objekt.Fahrzeug_Bestand)
                labeledField("Inventarnummer", objekt.Inventarnummer)
                labeledField("Gerätenummer", objekt.Geraetenummer)
            }
        }
        .padding(.vertical, 4)
    }
 
    @ViewBuilder
    private func labeledField(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "–" : value)
                .font(.caption)
        }
    }
}
