//
//  UnchangedListView.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

import SwiftUI

/// A SwiftUI view that displays a read-only list of unchanged inventory items (`Bestandsobjekt`).
///
/// UnchangedListView presents a `List` of provided items, sorted by their `Sachnummer`
/// in ascending order. Each row is rendered using `BestandsobjektRow`.
/// The navigation bar title reflects the number of items shown, formatted as
/// "Unverändert (<count>)".
///
/// Usage:
/// - Initialize with an array of `Bestandsobjekt`.
/// - Embed within a `NavigationStack`/`NavigationView` to show the navigation title.
///
/// Assumptions:
/// - `Bestandsobjekt` conforms to `Identifiable` (or otherwise provides an `id`) for use in `List`.
/// - `Bestandsobjekt` exposes a `Sachnummer` property that is `Comparable` (e.g., `String`)
///   to enable sorting.
/// - `BestandsobjektRow` is a SwiftUI view capable of rendering a single `Bestandsobjekt`.
///
/// - Parameter items: The collection of unchanged inventory objects to display.
struct UnchangedListView: View {
    let items: [Bestandsobjekt]

    var body: some View {
        List(items.sorted { $0.Sachnummer < $1.Sachnummer }) { objekt in
            BestandsobjektRow(objekt: objekt)
        }
        .navigationTitle("Unverändert (\(items.count))")
    }
}
