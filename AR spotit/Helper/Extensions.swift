//
//  Extensions.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-17.
//

import Foundation
import SwiftUI
import ARKit

extension String {
    var containsEmoji: Bool {
        return unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }

}

extension Character {
    var isEmoji: Bool {
        return self.unicodeScalars.contains { scalar in
            scalar.properties.isEmoji ||
            (scalar.value >= 0x1F600 && scalar.value <= 0x1F64F) || // Emoticons
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F5FF) || // Misc Symbols and Pictographs
            (scalar.value >= 0x1F680 && scalar.value <= 0x1F6FF) || // Transport and Map
            (scalar.value >= 0x2600 && scalar.value <= 0x26FF) ||   // Misc Symbols
            (scalar.value >= 0x2700 && scalar.value <= 0x27BF) ||   // Dingbats
            (scalar.value >= 0xFE00 && scalar.value <= 0xFE0F) ||   // Variation Selectors
            (scalar.value >= 0x1F900 && scalar.value <= 0x1F9FF) || // Supplemental Symbols and Pictographs
            (scalar.value >= 0x1F1E6 && scalar.value <= 0x1F1FF)    // Flags
        }
    }
}

extension matrix_float4x4 {
    static func translation(_ t: SIMD3<Float>) -> matrix_float4x4 {
        var result = matrix_identity_float4x4
        result.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1.0)
        return result
    }
}
