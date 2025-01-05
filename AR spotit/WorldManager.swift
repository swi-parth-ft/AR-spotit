//
//  WorldManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//

import ARKit

class WorldManager: ObservableObject {
    @Published var savedWorlds: [WorldModel] = [] // List of saved worlds
    
    init() {
        loadSavedWorlds()
    }
    
    func saveWorldMap(for roomName: String, sceneView: ARSCNView) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap else {
                print("Error saving world map: \(error?.localizedDescription ?? "No world map available.")")
                return
            }
            
            // Check if a world with the same name already exists
            if let worldIndex = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                let existingWorld = self.savedWorlds[worldIndex]
                
                // Delete the previous world file if it exists
                do {
                    if FileManager.default.fileExists(atPath: existingWorld.filePath.path) {
                        try FileManager.default.removeItem(at: existingWorld.filePath)
                        print("Deleted previous world map at: \(existingWorld.filePath.path)")
                    }
                    
                    // Update the existing WorldModel in savedWorlds
                    self.savedWorlds[worldIndex] = WorldModel(name: roomName)
                } catch {
                    print("Error deleting previous world map: \(error.localizedDescription)")
                }
            } else {
                // Add a new WorldModel if it doesn't exist
                let newWorld = WorldModel(name: roomName)
                self.savedWorlds.append(newWorld)
            }
            
            // Save the new world map
            let world = self.savedWorlds.first(where: { $0.name == roomName })!
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: world.filePath)
                self.saveWorldList()
                
                print("World map for \(roomName) saved successfully at: \(world.filePath.path)")
            } catch {
                print("Error while saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    func loadWorldMap(for roomName: String, sceneView: ARSCNView) {
        print("Attempting to load world map for room: \(roomName)")
        print("Available saved worlds: \(savedWorlds.map { $0.name })")
        
        guard let world = savedWorlds.first(where: { $0.name == roomName }) else {
            print("No saved world found with the name: \(roomName)")
            return
        }
        
        guard FileManager.default.fileExists(atPath: world.filePath.path) else {
            print("File not found at path: \(world.filePath.path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: world.filePath)
            print("Data loaded successfully from: \(world.filePath.path). Size: \(data.count) bytes")
            let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            
            guard let worldMap = unarchivedMap else {
                print("Failed to unarchive ARWorldMap.")
                return
            }
            
            sceneView.session.pause()
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.initialWorldMap = worldMap
            configuration.planeDetection = [.horizontal, .vertical]
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            print("World map for \(roomName) loaded successfully.")
        } catch {
            print("Error loading ARWorldMap for \(roomName): \(error.localizedDescription)")
        }
    }
    
    private func saveWorldList() {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try JSONEncoder().encode(savedWorlds)
            try data.write(to: fileURL)
            print("World list saved at: \(fileURL.path)")
        } catch {
            print("Error saving world list: \(error.localizedDescription)")
        }
    }

    private func loadSavedWorlds() {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            savedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
            print("Saved worlds loaded: \(savedWorlds.map { $0.name })")
        } catch {
            print("No saved world list found or failed to decode: \(error.localizedDescription)")
        }
    }
    
    func getAnchorNames(for worldName: String) -> [String] {
        guard let world = savedWorlds.first(where: { $0.name == worldName }) else {
            print("No saved world found with the name: \(worldName)")
            return []
        }
        
        if !FileManager.default.fileExists(atPath: world.filePath.path) {
            print("File not found at path: \(world.filePath.path)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: world.filePath)
            if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                let anchorNames = unarchivedMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
                print("Found anchors in \(worldName): \(anchorNames)")
                return anchorNames
            } else {
                print("Failed to unarchive ARWorldMap for \(worldName).")
                return []
            }
        } catch {
            print("Error loading ARWorldMap for \(worldName): \(error.localizedDescription)")
            return []
        }
    }
}
