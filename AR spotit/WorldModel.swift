//
//  WorldModel.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//


import Foundation

struct WorldModel: Identifiable, Codable {
    let id: UUID
    let name: String // Room name (e.g., "Living Room", "Bedroom")
    let filePath: URL // File path to the saved ARWorldMap
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.filePath = WorldModel.documentsDirectory.appendingPathComponent("\(name)_worldMap")
    }
    
    // Helper to get the documents directory
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}