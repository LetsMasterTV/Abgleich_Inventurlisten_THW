//
//  FileImporterButtonStyle.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 13.08.2026.
//

import SwiftUI

struct FileImporterButtonStyle: ButtonStyle {
    var title: String = "Datei auswählen"
    var subtitle: String? = "oder per Drag & Drop hierher ziehen"
    var systemImage: String = "doc.badge.plus"
    var isSelected: Bool = false
    let THW_gelb = Color(red: 1.0, green: 1.0, blue: 0.0, opacity: 1.0)
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 12) {
            // Icon mit leichtem Hintergrundkreis
            ZStack {
                Circle()
                    .fill(THW_gelb.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(THW_gelb)
            }
            
            // Text-Informationen
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(THW_gelb)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundColor(THW_gelb)
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: (NSScreen.main?.visibleFrame.width ?? 800) * (1.0 / 3.0))        // Hintergrund & abgerundete Ecken
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: (0.0 / 255.0), green: (56.0 / 255.0), blue: (123.0 / 255.0), opacity: 1.0))
        )
        // Gestrichelter Rahmen für den typischen "Drop-Zone" Look
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    style: isSelected ? StrokeStyle(lineWidth: 2) : StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundColor(isSelected ? .green : (configuration.isPressed ? THW_gelb : THW_gelb.opacity(0.4)))
                )
        .overlay(
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                                .background(Circle().fill(.white).padding(2)) // Weisser Rand für Kontrast
                                .offset(x: -8, y: 8) // Nach innen versetzt
                        }
                    },
                    alignment: .topTrailing
                )
        // Visuelles Feedback beim Drücken (Skalierung + Deckkraft)
        .opacity(configuration.isPressed ? 0.55 : 1.0)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Praktischer Extension-Shortcut für saubereren Code
extension ButtonStyle where Self == FileImporterButtonStyle {
    static var fileImporter: FileImporterButtonStyle {
        FileImporterButtonStyle()
    }
    
    static func fileImporter(
        title: String,
        subtitle: String? = nil,
        systemImage: String = "doc.badge.plus",
        isSelected: Bool
    ) -> FileImporterButtonStyle {
        FileImporterButtonStyle(title: title, subtitle: subtitle, systemImage: systemImage,isSelected: isSelected)
    }
}
