//
//  TreeDisclosureView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 04.08.2026.
//
import SwiftUI

struct TreeDisclosureView: View {
    let node: HierarchyNode
    @Binding var expanded: Set<UUID>
    let content: (HierarchyNode) -> AnyView

    var body: some View {
        let isExpanded = Binding<Bool>(
            get: { expanded.contains(node.id) },
            set: { newValue in
                if newValue { expanded.insert(node.id) } else { expanded.remove(node.id) }
            }
        )

        if node.children.isEmpty {
            content(node)
        } else {
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.children) { child in
                        TreeDisclosureView(node: child, expanded: $expanded, content: content)
                            .padding(.leading, 8)
                    }
                }
            } label: {
                content(node)
            }
            
        }
    }
}
