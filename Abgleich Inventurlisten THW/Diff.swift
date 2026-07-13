//
//  Untitled.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

/// A value type that represents the differences between two collections of `Bestandsobjekt`
/// parsed from XLSX sources (e.g., two inventory lists).
///
/// Use `XLSXDiff` to categorize how items changed between an "old" and a "new" dataset:
/// - `added`: Items present in the new dataset but not in the old.
/// - `removed`: Items present in the old dataset but not in the new.
/// - `modified`: Items present in both datasets that differ in at least one relevant field.
///   Each tuple provides the previous (`alt`) and the updated (`new`) state of the item.
/// - `unchanged`: Items present in both datasets that are identical according to the chosen
///   equality/comparison criteria.
///
/// The `hasChanges` computed property is a convenience flag indicating whether any additions,
/// removals, or modifications exist (it ignores `unchanged`).
///
/// Typical usage:
/// - Generate an `XLSXDiff` after comparing two lists.
/// - Present the results in a UI, export a change report, or drive follow-up actions
///   (e.g., create tasks for added or removed inventory).
///
/// - Important: The semantics of "modified" and "unchanged" depend on how `Bestandsobjekt`
///   equality or comparison is defined elsewhere in the project. Ensure that the same criteria
///   are used when constructing the diff.
///
/// - Note: The term `alt` (German for "old") is used for the previous state, and `new` for the
///   updated state within the `modified` tuples.
///
/// - SeeAlso: `Bestandsobjekt`
struct XLSXDiff {
    let added: [Bestandsobjekt]
    let removed: [Bestandsobjekt]
    let modified: [(alt: Bestandsobjekt, new: Bestandsobjekt)]
    let unchanged: [Bestandsobjekt]
    
    var hasChanges: Bool {
        !added.isEmpty || !removed.isEmpty || !modified.isEmpty
    }
}


