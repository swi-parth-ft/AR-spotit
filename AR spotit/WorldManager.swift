//
//  WorldManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//

import ARKit
import CloudKit

class WorldManager: ObservableObject {
    @Published var savedWorlds: [WorldModel] = [] // List of saved worlds
    private let recordType = "ARWorldMapRecord"
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
                
                self.uploadARWorldMapToCloudKit(roomName: roomName, data: data) {
                    print("Sync to CloudKit complete for \(roomName).")
                }
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
            loadFromCloudKit(roomName: roomName, sceneView: sceneView)
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
    
    func getAnchorNames(for worldName: String, completion: @escaping ([String]) -> Void) {
        guard let world = savedWorlds.first(where: { $0.name == worldName }) else {
            print("No saved world found with the name: \(worldName)")
            completion([])
            return
        }
        
        // 1) Check local file
        if !FileManager.default.fileExists(atPath: world.filePath.path) {
            print("File not found at path: \(world.filePath.path). Trying CloudKit...")
            
            // 2) If local file doesn't exist, load from CloudKit
            loadWorldMapDataFromCloudKitOnly(roomName: worldName) { [weak self] cloudMap in
                guard let cloudMap = cloudMap else {
                    // Couldn’t load from CloudKit either
                    completion([])
                    return
                }
                // 3) We got the ARWorldMap from CloudKit. Extract anchors
                let anchorNames = cloudMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
                print("Found anchors in \(worldName) (from CloudKit): \(anchorNames)")
                completion(anchorNames)
            }
        } else {
            // 4) If local file exists, just read it
            do {
                let data = try Data(contentsOf: world.filePath)
                if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    let anchorNames = unarchivedMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
                    print("Found anchors in \(worldName): \(anchorNames)")
                    completion(anchorNames)
                } else {
                    print("Failed to unarchive ARWorldMap for \(worldName).")
                    completion([])
                }
            } catch {
                print("Error loading ARWorldMap for \(worldName): \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    private func uploadARWorldMapToCloudKit(roomName: String, data: Data, completion: (() -> Void)? = nil) {
        // 1) Write data to a temp file so we can create a CKAsset
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(roomName)_tempWorldMap")
        
        do {
            try data.write(to: tempURL)
        } catch {
            print("Error writing ARWorldMap data to temp file: \(error.localizedDescription)")
            completion?()
            return
        }
        
        // 2) Create the CKRecord
        let record = CKRecord(recordType: recordType)
        record["roomName"] = roomName as CKRecordValue
        record["mapAsset"] = CKAsset(fileURL: tempURL)
        
        // 3) Save to private database
        let privateDB = CKContainer.default().privateCloudDatabase
        privateDB.save(record) { savedRecord, error in
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            if let error = error {
                print("Error uploading ARWorldMap to CloudKit: \(error.localizedDescription)")
            } else {
                print("ARWorldMap for \(roomName) successfully uploaded to CloudKit.")
            }
            
            completion?()
        }
    }
    
    private func loadFromCloudKit(roomName: String, sceneView: ARSCNView) {
        print("Attempting to load world map from CloudKit for \(roomName).")
        
        let privateDB = CKContainer.default().privateCloudDatabase
        
        // Query for the record
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error querying CloudKit: \(error.localizedDescription)")
                return
            }
            
            guard let record = records?.first else {
                print("No record found in CloudKit for \(roomName).")
                return
            }
            
            // Retrieve the CKAsset
            guard let asset = record["mapAsset"] as? CKAsset,
                  let assetFileURL = asset.fileURL else {
                print("No valid mapAsset found in CloudKit record.")
                return
            }
            
            do {
                // Read data from the asset’s file
                let data = try Data(contentsOf: assetFileURL)
                // Convert data to ARWorldMap
                if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    
                    // Re-save locally for offline use
                    DispatchQueue.main.async {
                        self.saveLocallyAfterCloudDownload(roomName: roomName, data: data)
                        
                        // Now run AR session
                        sceneView.session.pause()
                        
                        let configuration = ARWorldTrackingConfiguration()
                        configuration.initialWorldMap = unarchivedMap
                        configuration.planeDetection = [.horizontal, .vertical]
                        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                        
                        print("World map for \(roomName) loaded successfully from CloudKit.")
                    }
                }
            } catch {
                print("Error reading data from CloudKit asset: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveLocallyAfterCloudDownload(roomName: String, data: Data) {
        // 1) If we already have an entry, remove old file
        if let index = savedWorlds.firstIndex(where: { $0.name == roomName }) {
            let existingWorld = savedWorlds[index]
            
            if FileManager.default.fileExists(atPath: existingWorld.filePath.path) {
                try? FileManager.default.removeItem(at: existingWorld.filePath)
            }
            savedWorlds[index] = WorldModel(name: roomName)
        } else {
            savedWorlds.append(WorldModel(name: roomName))
        }
        
        // 2) Save data
        let world = savedWorlds.first(where: { $0.name == roomName })!
        do {
            try data.write(to: world.filePath)
            saveWorldList()
            print("Re-saved \(roomName) locally after CloudKit download at: \(world.filePath.path)")
        } catch {
            print("Failed to save locally after CloudKit download: \(error.localizedDescription)")
        }
    }
    
    private func loadWorldMapDataFromCloudKitOnly(roomName: String, completion: @escaping (ARWorldMap?) -> Void) {
        print("Attempting to load world map data (only) from CloudKit for \(roomName).")
        
        let privateDB = CKContainer.default().privateCloudDatabase
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDB.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                print("Error querying CloudKit: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let record = records?.first else {
                print("No record found in CloudKit for \(roomName).")
                completion(nil)
                return
            }
            
            // Retrieve the CKAsset
            guard let asset = record["mapAsset"] as? CKAsset,
                  let assetFileURL = asset.fileURL else {
                print("No valid mapAsset found in CloudKit record.")
                completion(nil)
                return
            }
            
            do {
                // Read data from the asset’s file
                let data = try Data(contentsOf: assetFileURL)
                // Convert data to ARWorldMap
                if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    
                    // Re-save locally so we have it next time
                    DispatchQueue.main.async {
                        self?.saveLocallyAfterCloudDownload(roomName: roomName, data: data)
                        completion(unarchivedMap)
                    }
                } else {
                    print("Failed to unarchive ARWorldMap from CloudKit asset data.")
                    completion(nil)
                }
            } catch {
                print("Error reading data from CloudKit asset: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}

