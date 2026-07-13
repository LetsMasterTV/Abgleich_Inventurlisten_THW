//
//  UnchangedListView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

struct UnchangedListView: View {
    let items: [Bestandsobjekt]

    var body: some View {
        List(items.sorted { $0.Sachnummer < $1.Sachnummer }) { objekt in
            BestandsobjektRow(objekt: objekt)
        }
        .navigationTitle("Unverändert (\(items.count))")
    }
}
