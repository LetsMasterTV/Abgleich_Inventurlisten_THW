
//  TreeDisclosureView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 04.08.2026.
//
import SwiftUI

struct TreeDisclosureView<Content: View>: View {
    let node: HierarchyNode
    @Binding var expanded: Set<String>
    let visibleKeys: Set<String>
    @ViewBuilder let content: (HierarchyNode) -> Content

    private let globalSpacing: CGFloat = 7
    
    @ViewBuilder
    var body: some View {
        
        if visibleKeys.contains(node.id) {
            let isExpanded = Binding<Bool>(
                get: { expanded.contains(node.id) },
                set: { newValue in
                    if newValue { expanded.insert(node.id) } else { expanded.remove(node.id) }
                }
            )
            
            // Filtere Kinder: nur solche anzeigen, deren key in visibleKeys ist
            let visibleChildren = node.children.filter { visibleKeys.contains($0.id) }
            
            if visibleChildren.isEmpty {
                content(node)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                DisclosureGroup(isExpanded: isExpanded) {
                    HStack(alignment: .top, spacing: 5) {
                        GeometryReader { geometry in
                                    Path { path in
                                        // Startpunkt oben (2pt eingerückt)
                                        path.move(to: CGPoint(x: 2, y: 4))
                                        
                                        // Vertikale Linie nach unten ziehen (bis kurz vor das Ende der Gesamthöhe)
                                        // -12 sorgt dafür, dass der Knick auf Höhe des letzten Textes stoppt
                                        let endY = geometry.size.height - 12
                                        path.addLine(to: CGPoint(x: 2, y: endY))
                                        
                                        // Der Knick nach rechts (8pt lang)
                                        path.addLine(to: CGPoint(x: 10, y: endY))
                                    }
                                    .stroke(
                                        Color.primary.opacity(0.18),
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                                    )
                                }
                                // Der Frame reserviert exakt den Platz für die Linie im Layout
                                .frame(width: 12)
                                .padding(.leading, 20)
                    
                        
                        LazyVStack(alignment: .leading, spacing: 0) { // TODO: Abstand einstellen
                            ForEach(visibleChildren) { child in
                                TreeDisclosureView(node: child, expanded: $expanded, visibleKeys: visibleKeys, content: content)
                                    .padding(.leading, 8)
                                    .padding(.vertical, globalSpacing)
                            }
                        }
                        .padding(.leading, 5)
                    }
                    
                } label: {
                    content(node)
                }
                .disclosureGroupStyle(ColoredDisclosureGroupStyle(backgroundColor: rowColor(for: node)))
            }
        }
    }
}

 func rowColor(for node: HierarchyNode) -> Color {
    switch node.status {
    case .added: return Color.green.opacity(0.18)
    case .removed: return Color.red.opacity(0.18)
    case .modified: return Color.orange.opacity(0.18)
    case .unchanged: return Color.primary.opacity(0.05)
    }
}


