//
//  Untitled.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

struct XLSXDiff {
    let added: [Bestandsobjekt]
    let removed: [Bestandsobjekt]
    let modified: [(alt: Bestandsobjekt, new: Bestandsobjekt)]
    let unchanged: [Bestandsobjekt]
    
    var hasChanges: Bool {
        !added.isEmpty || !removed.isEmpty || !modified.isEmpty
    }
}


