//
//  World.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-05.
//


import SwiftData
import SwiftUI

@Model
class World {
    @Attribute(.unique) var name: String
    var anchors: [Anchor] = []

    init(name: String) {
        self.name = name
    }
}

@Model
class Anchor {
    var name: String
    var transformData: Data

    init(name: String, transformData: Data) {
        self.name = name
        self.transformData = transformData
    }
}
