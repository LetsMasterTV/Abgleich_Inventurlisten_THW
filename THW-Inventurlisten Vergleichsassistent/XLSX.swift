//
//  XLSX.swift
//  Abgleich Inventurlisten THW
//
//  Created by Kai Sebastian Bühner on 12.07.2026.
//

/**
 
 */

import UniformTypeIdentifiers

extension UTType {
    static var xlsx: UTType {
        UTType(filenameExtension: "xlsx") ?? UTType(exportedAs: "org.openxmlformats.spreadsheetml.sheet")
    }
}
