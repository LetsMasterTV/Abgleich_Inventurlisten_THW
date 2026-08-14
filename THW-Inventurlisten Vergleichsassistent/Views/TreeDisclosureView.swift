
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

    private let globalSpacing: CGFloat = 8
    
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
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.18)) // Farbe & Transparenz des Strichs
                            .frame(width: 2)                  // Dicke des Strichs (2 pt)
                            .padding(.leading, 20)
                            .padding(.top, -globalSpacing - 4)    // Zieht den Strich nach oben in den Header-Bereich hinein
                        
                        
                        LazyVStack(alignment: .leading, spacing: 0) { // TODO: Abstand einstellen
                            ForEach(visibleChildren) { child in
                                TreeDisclosureView(node: child, expanded: $expanded, visibleKeys: visibleKeys, content: content)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.leading, 5)
                    }
                    .padding(.top, -4)
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
    case .unchanged: return Color.primary.opacity(0.03)
    }
}


