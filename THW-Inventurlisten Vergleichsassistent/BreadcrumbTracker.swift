//
//  BreadcrumbTracker.swift
//  THW-Inventurlisten Vergleichsassistent
//
//  Created by Kai Sebastian Bühner on 17.08.2026.
//

import SwiftUI

@MainActor
@Observable
final class BreadcrumbTracker {
    var breadcrumbParts: [String] = []
    private var nodePositions: [String: CGFloat] = [:]
    private var nodeReferences: [String: HierarchyNode] = [:]

    func updatePosition(id: String, minY: CGFloat, node: HierarchyNode) {
        nodePositions[id] = minY
        nodeReferences[id] = node
        computeBreadcrumb()
    }

    func removeNode(id: String) {
        nodePositions.removeValue(forKey: id)
        nodeReferences.removeValue(forKey: id)
        computeBreadcrumb()
    }

    private func computeBreadcrumb() {
        guard !nodePositions.isEmpty else { return }

        var passedID: String?
        var passedY: CGFloat?
        var nearestID: String?
        var nearestY: CGFloat?

        for (id, y) in nodePositions {
            if y <= 20, passedY == nil || y > passedY! {
                passedID = id
                passedY = y
            }
            if nearestY == nil || y < nearestY! {
                nearestID = id
                nearestY = y
            }
        }

        guard let topID = passedID ?? nearestID,
              let node = nodeReferences[topID] else { return }

        var parts: [String] = []
        var current: HierarchyNode? = node

        while let currentNode = current {
            let beschreibung = currentNode.objekt.Beschreibung.trimmingCharacters(in: .whitespacesAndNewlines)
            parts.append(beschreibung.isEmpty ? currentNode.objekt.key : beschreibung)
            current = currentNode.parent
        }

        parts.reverse()
        if breadcrumbParts != parts {
            breadcrumbParts = parts
        }
    }
}
