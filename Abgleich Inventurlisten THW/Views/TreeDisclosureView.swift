
//  TreeDisclosureView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 04.08.2026.
//
import SwiftUI

struct TreeDisclosureView: View {
    let node: HierarchyNode
    @Binding var expanded: Set<UUID>
    let visibleKeys: Set<String>
    let content: (HierarchyNode) -> AnyView

    var body: some View {
        let isExpanded = Binding<Bool>(
            get: { expanded.contains(node.id) },
            set: { newValue in
                if newValue { expanded.insert(node.id) } else { expanded.remove(node.id) }
            }
        )

        // Filtere Kinder: nur solche anzeigen, deren key in visibleKeys ist
        let visibleChildren = node.children.filter { visibleKeys.contains($0.objekt.key) }

        if visibleChildren.isEmpty {
            content(node)
        } else {
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(visibleChildren) { child in
                        TreeDisclosureView(node: child, expanded: $expanded, visibleKeys: visibleKeys, content: content)
                            .padding(.leading, 8)
                    }
                }
            } label: {
                content(node)
            }
        }
    }
}
