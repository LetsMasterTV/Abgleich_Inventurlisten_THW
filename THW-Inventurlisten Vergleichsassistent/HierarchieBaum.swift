//
//  HierarchieBaum.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 03.08.2026.
//
import Foundation

enum NodeStatus {
    case added
    case removed
    case modified(old: Bestandsobjekt)
    case unchanged
}
 
final class HierarchyNode: Identifiable {
    let id: String
    let objekt: Bestandsobjekt
    let status: NodeStatus
    var children: [HierarchyNode]
    weak var parent: HierarchyNode?
 
    init(id: String, objekt: Bestandsobjekt, status: NodeStatus, children: [HierarchyNode] = []) {
        self.id = id
        self.objekt = objekt
        self.status = status
        self.children = children
    }

    var childrenOrNil: [HierarchyNode]? { children.isEmpty ? nil : children }
}

extension HierarchyNode {
    // Hilfseigenschaft, um den unkomplizierten Fallback im UI zu prüfen
    var statusIsUnchanged: Bool {
        if case .unchanged = self.status { return true }
        return false
    }
}

 
/// Baut aus einer flachen, geordneten Liste (Original-Dateireihenfolge!) einen vollständigen Baum.
/// Baut aus einer flachen, geordneten Liste (Original-Dateireihenfolge!) einen vollständigen Baum.
func buildFullHierarchy(
    newItems: [Bestandsobjekt],
    oldItems: [Bestandsobjekt],
    diff: XLSXDiff
) -> [HierarchyNode] {
    let newItemsSorted = newItems.sorted { $0.Zeile < $1.Zeile }
    let oldItemsSorted = oldItems.sorted { $0.Zeile < $1.Zeile }

    let addedIDs = Set(diff.added.map { $0.id })
    let modifiedByID = Dictionary(uniqueKeysWithValues: diff.modified.map { ($0.new.id, $0.alt) })
    let removedIDs = Set(diff.removed.map { $0.id })

    func ermittleStatus(for item: Bestandsobjekt) -> NodeStatus {
        if addedIDs.contains(item.id) { return .added }
        if let old = modifiedByID[item.id] { return .modified(old: old) }
        return .unchanged
    }

    var roots: [HierarchyNode] = []
    var stack: [(level: Int, node: HierarchyNode)] = []

    // Key-Mapping auf Basis des kombinierten Pfads, um präzise Elternzuordnung zu erlauben
    var nodesByFullPath: [String: HierarchyNode] = [:]

    let parentsNew = Inventurliste.computeParents(for: newItemsSorted)
    let newPaths = Inventurliste.vollePfade(fuer: newItemsSorted, parents: parentsNew)

    // 1. Neue und modifizierte Elemente in die Hierarchie einbauen
    for item in newItemsSorted {
        // Leere oder ungültige Ebenen werden als Hauptebene (0) gewertet
        let level = Int(item.Ebene) ?? 0
        let vollerPfad = newPaths[item.id] ?? item.key
        let uniqueID = "\(vollerPfad) [Neu:#\(item.Zeile) \(item.key))]"
        
        let node = HierarchyNode(id: uniqueID, objekt: item, status: ermittleStatus(for: item))
        nodesByFullPath[vollerPfad] = node
        

        while let last = stack.last, last.level >= level {
            stack.removeLast()
        }

        // Wenn level 0 ist oder der Stack leer ist, ist es ein Wurzel-Element ganz oben (z.B. Fahrzeug)
        if level == 0 || stack.isEmpty {
            roots.append(node)
        } else if let parent = stack.last {
            parent.node.children.append(node)
            node.parent = parent.node
        } else {
            roots.append(node)
        }
        stack.append((level, node))
    }

    // 2. DYNAMISCHE INJEKTION: Entfernte Objekte unter dem alten Eltern-Pfad einhängen
    let parentsOld = Inventurliste.computeParents(for: oldItemsSorted)
    let oldPaths = Inventurliste.vollePfade(fuer: oldItemsSorted, parents: parentsOld)
    let removedOrdered = oldItemsSorted.filter { removedIDs.contains($0.id) }

    for item in removedOrdered {

        // Bestimme den exakten alten Pfad, an dem das gelöschte Objekt stand
        let alterVollerPfad = oldPaths[item.id] ?? item.key
        let uniqueID = "\(alterVollerPfad) [Alt:#\(item.Zeile) \(item.key)]"
        let node = HierarchyNode(id: uniqueID, objekt: item, status: .removed)

        
        nodesByFullPath[alterVollerPfad] = node

        // Finde den Vater-Knoten im neuen Anzeige-Baum über den alten Elternpfad
        var attached = false
        if let parentObjekt = parentsOld[item.id] {
            let vaterPfad = oldPaths[parentObjekt.id] ?? parentObjekt.key

            // Wenn der Vater im neuen Baum existiert, hänge das gelöschte Objekt dort an
            if let parentNode = nodesByFullPath[vaterPfad] {
                parentNode.children.append(node)
                node.parent = parentNode
                attached = true
            }
        }

        if !attached {
            roots.append(node) // Fallback an die Wurzel, falls der gesamte Ast gelöscht wurde
        }
    }

    // Sortierung der Kinder nach originaler Excel-Reihenfolge wiederherstellen
    func sortiereKinder(von knoten: HierarchyNode) {
        knoten.children.sort { $0.objekt.Zeile < $1.objekt.Zeile }
        for kind in knoten.children {
            sortiereKinder(von: kind)
        }
    }
    roots.sort { $0.objekt.Zeile < $1.objekt.Zeile }
    for root in roots { sortiereKinder(von: root) }

    return roots
}


/// Reduziert einen vollständigen Baum auf die Knoten, die SELBST geändert/neu/entfernt sind,
/// oder mindestens einen solchen Nachfahren enthalten. Reine Kontext-Vorfahren bleiben erhalten
/// (damit man überhaupt zur Änderung navigieren kann), rein unveränderte Äste fallen komplett weg.
func pruneToChangesOnly(_ nodes: [HierarchyNode]) -> (nodes: [HierarchyNode], expandedKeys: Set<String>, matchedKeys: Set<String>) {
    var resultNodes: [HierarchyNode] = []
    var expandedKeys: Set<String> = []
    var matchedKeys: Set<String> = []
    
    for node in nodes {
        let (prunedChildren, childKeys, childmatchedKeys) = pruneToChangesOnly(node.children)

        let selfIsChanged: Bool = {
            if case .unchanged = node.status { return false }
            return true
        }()
            
        
        
        if selfIsChanged || !prunedChildren.isEmpty {
            let newNode = HierarchyNode(id: node.id, objekt: node.objekt, status: node.status, children: prunedChildren)
            resultNodes.append(newNode)

            // Sammle die Keys der Kinder und füge den eigenen Key hinzu, falls Kinder existieren
            expandedKeys.formUnion(childKeys)
            if !prunedChildren.isEmpty {
                expandedKeys.insert(newNode.id)
            }
            
            matchedKeys.formUnion(childmatchedKeys)
            if selfIsChanged {
                matchedKeys.insert(newNode.id)
            }
        }
    }

    return (resultNodes, expandedKeys, matchedKeys)
}
