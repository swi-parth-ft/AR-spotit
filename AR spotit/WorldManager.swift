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
    
    // Save the ARWorldMap for a specific room
    func saveWorldMap(for roomName: String, sceneView: ARSCNView) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap else {
                print("Error saving world map: \(error?.localizedDescription ?? "No world map available.")")
                return
            }
            
            let world = WorldModel(name: roomName)
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: world.filePath)
                self.savedWorlds.append(world)
                self.saveWorldList()
                print("World map for \(roomName) saved successfully.")
            } catch {
                print("Error while saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    // Load the ARWorldMap for a specific room
    func loadWorldMap(for roomName: String, sceneView: ARSCNView) {
        guard let world = savedWorlds.first(where: { $0.name == roomName }),
              let data = try? Data(contentsOf: world.filePath),
              let unarchivedMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            print("No saved map found for \(roomName).")
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.initialWorldMap = unarchivedMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("World map for \(roomName) loaded successfully.")
    }
    
    // Save the list of saved worlds to disk
    private func saveWorldList() {
        let fileURL = WorldModel.documentsDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try JSONEncoder().encode(savedWorlds)
            try data.write(to: fileURL)
        } catch {
            print("Error saving world list: \(error.localizedDescription)")
        }
    }
    
    // Load the list of saved worlds from disk
    private func loadSavedWorlds() {
        let fileURL = WorldModel.documentsDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            savedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
        } catch {
            print("No saved world list found or failed to decode.")
        }
    }
}