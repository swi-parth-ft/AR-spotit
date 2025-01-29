//
//  to.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-29.
//


import Foundation

// Define a struct to represent the key for mapping
struct AnchorKey: Codable, Hashable {
    let worldName: String
    let anchorName: String
}

// Define a class to manage the mapping
class AnchorUUIDManager {
    static let shared = AnchorUUIDManager()
    
    private let userDefaultsKey = "AnchorUUIDMapping"
    private var mapping: [AnchorKey: UUID] = [:]
    
    private init() {
        loadMapping()
    }
    
    // Retrieve or generate a UUID for a given world and anchor
    func uuid(for worldName: String, anchorName: String) -> UUID {
        let key = AnchorKey(worldName: worldName, anchorName: anchorName)
        if let existingUUID = mapping[key] {
            return existingUUID
        } else {
            let newUUID = UUID()
            mapping[key] = newUUID
            saveMapping()
            return newUUID
        }
    }
    
    // Load the mapping from UserDefaults
    private func loadMapping() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedMapping = try? JSONDecoder().decode([AnchorKey: UUID].self, from: data) {
            mapping = decodedMapping
        }
    }
    
    // Save the mapping to UserDefaults
    private func saveMapping() {
        if let encodedMapping = try? JSONEncoder().encode(mapping) {
            UserDefaults.standard.set(encodedMapping, forKey: userDefaultsKey)
        }
    }
}