//
//  RowDisclosureStyle.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 13.08.2026.
//
import SwiftUI

struct ColoredDisclosureGroupStyle: DisclosureGroupStyle {
    let backgroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) { // TODO: Abstand einstellen
            // Der Header (Pfeil + Label)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // Der echte System-Chevron mit nativer Drehung
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.foreground)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))

                    configuration.label
                }
                .padding(.vertical, 4)
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .background(backgroundColor) // Färbt JETZT Pfeil + Label gemeinsam ein!
                .cornerRadius(6)
            }
            .buttonStyle(.plain) // Entfernt den grauen Standard-Button-Hintergrund

            // Der aufgeklappte Inhalt (Kinder)
            if configuration.isExpanded {
                configuration.content
                    .padding(.top, 0) // TODO: Abstand einstellen
                    .padding(.bottom, 2) //Abstand nach allen Kinder Elementen
            }
        }
    }
}
