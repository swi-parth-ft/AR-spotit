import ARKit
import CloudKit

class WorldManager: ObservableObject {
    @Published var savedWorlds: [WorldModel] = [] // List of saved worlds
    private let recordType = "ARWorldMapRecord"

    // MARK: - Initialization
    init() {
        loadSavedWorlds() // Load local data first
        fetchWorldNamesFromCloudKit {
            print("Data synced with CloudKit.")
            
            // Fetch missing worlds and save them locally
            for world in self.savedWorlds {
                if !FileManager.default.fileExists(atPath: world.filePath.path) {
                    print("Fetching missing data for world: \(world.name)")
                    self.loadWorldMapDataFromCloudKitOnly(roomName: world.name) { _ in
                        print("Fetched and saved \(world.name) locally.")
                    }
                }
            }
        }
    }

    // MARK: - Save ARWorldMap
    func saveWorldMap(for roomName: String, sceneView: ARSCNView) {
        sceneView.session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self = self, let map = worldMap else {
                print("Error saving world map: \(error?.localizedDescription ?? "No world map available.")")
                return
            }
            
            let timestamp = Date()
            if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                self.savedWorlds[index].lastModified = timestamp
            } else {
                self.savedWorlds.append(WorldModel(name: roomName, lastModified: timestamp))
            }
            
            let world = self.savedWorlds.first { $0.name == roomName }!
            
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                let filePath = world.filePath
                try data.write(to: filePath)
                self.saveWorldList()
                
                print("World map for \(roomName) saved locally at: \(filePath.path)")
                
                self.uploadARWorldMapToCloudKit(roomName: roomName, data: data, lastModified: timestamp) {
                    print("Sync to CloudKit complete for \(roomName).")
                }
            } catch {
                print("Error saving world map locally: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Load ARWorldMap
    func loadWorldMap(for roomName: String, sceneView: ARSCNView) {
        print("Attempting to load world map for room: \(roomName)")
        
        guard let world = savedWorlds.first(where: { $0.name == roomName }) else {
            print("No saved world found with the name: \(roomName)")
            return
        }
        
        let filePath = world.filePath
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("File not found at path: \(filePath.path). Trying CloudKit...")
            loadFromCloudKit(roomName: roomName, sceneView: sceneView)
            return
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            
            guard let worldMap = unarchivedMap else {
                print("Failed to unarchive ARWorldMap.")
                return
            }
            
            sceneView.session.pause()
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.initialWorldMap = worldMap
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.sceneReconstruction = .mesh // Ensure LiDAR reconstruction
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            print("World map for \(roomName) loaded successfully.")
        } catch {
            print("Error loading ARWorldMap for \(roomName): \(error.localizedDescription)")
        }
    }

    // MARK: - Save World List Locally
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

    // MARK: - Load Saved Worlds
    private func loadSavedWorlds() {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
            
            DispatchQueue.main.async {
                self.savedWorlds = decodedWorlds
                print("Saved worlds loaded: \(self.savedWorlds.map { $0.name })")
            }
        } catch {
            DispatchQueue.main.async {
                self.savedWorlds = []
                print("No saved world list found or failed to decode: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Upload to CloudKit
    private func uploadARWorldMapToCloudKit(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(roomName)_tempWorldMap")
        do {
            try data.write(to: tempURL)
        } catch {
            print("Error writing to temp file: \(error.localizedDescription)")
            completion?()
            return
        }
        
        let record = CKRecord(recordType: recordType)
        record["roomName"] = roomName as CKRecordValue
        record["mapAsset"] = CKAsset(fileURL: tempURL)
        record["lastModified"] = lastModified as CKRecordValue
        
        let privateDB = CKContainer.default().privateCloudDatabase
        privateDB.save(record) { savedRecord, error in
            try? FileManager.default.removeItem(at: tempURL)
            if let error = error {
                print("Error uploading to CloudKit: \(error.localizedDescription)")
            } else {
                print("ARWorldMap for \(roomName) successfully uploaded to CloudKit.")
            }
            completion?()
        }
    }

    // MARK: - Fetch from CloudKit
    func fetchWorldNamesFromCloudKit(completion: @escaping () -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "WorldListRecord", predicate: NSPredicate(format: "roomName != ''"))
        
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["roomName", "lastModified"], resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                var fetchedWorlds: [WorldModel] = []
                
                for (_, recordResult) in matchedResults {
                    switch recordResult {
                    case .success(let record):
                        let roomName = record["roomName"] as? String ?? "Unnamed"
                        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
                        
                        // Check if local data is older than CloudKit data
                        if let localWorld = self.savedWorlds.first(where: { $0.name == roomName }), lastModified > localWorld.lastModified {
                            print("Cloud data for \(roomName) is newer. Downloading...")
                            self.loadWorldMapDataFromCloudKitOnly(roomName: roomName) { _ in }
                        } else if !self.savedWorlds.contains(where: { $0.name == roomName }) {
                            // Add new world from CloudKit
                            fetchedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                        }
                    case .failure(let error):
                        print("Error fetching record: \(error.localizedDescription)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.savedWorlds.append(contentsOf: fetchedWorlds)
                    self.saveWorldList() // Save updated list locally
                    completion()
                }
                
            case .failure(let error):
                print("Error fetching world names from CloudKit: \(error.localizedDescription)")
                completion()
            }
        }
    }

    // MARK: - Helper Methods for CloudKit
    private func loadFromCloudKit(roomName: String, sceneView: ARSCNView) {
        print("Loading world map from CloudKit for \(roomName).")
        let privateDB = CKContainer.default().privateCloudDatabase
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDB.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                print("Error querying CloudKit: \(error.localizedDescription)")
                return
            }
            
            guard let record = records?.first else {
                print("No record found for \(roomName).")
                return
            }
            
            guard let asset = record["mapAsset"] as? CKAsset, let assetFileURL = asset.fileURL else {
                print("No valid mapAsset found.")
                return
            }
            
            do {
                let data = try Data(contentsOf: assetFileURL)
                if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    DispatchQueue.main.async {
                        self?.saveLocallyAfterCloudDownload(roomName: roomName, data: data, lastModified: Date())
                        
                        // Load into AR session
                        sceneView.session.pause()
                        let configuration = ARWorldTrackingConfiguration()
                        configuration.initialWorldMap = unarchivedMap
                        configuration.planeDetection = [.horizontal, .vertical]
                        configuration.sceneReconstruction = .mesh
                        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                        
                        print("World map for \(roomName) loaded from CloudKit.")
                    }
                } else {
                    print("Failed to unarchive ARWorldMap from CloudKit.")
                }
            } catch {
                print("Error reading CloudKit asset: \(error.localizedDescription)")
            }
        }
    }

    private func loadWorldMapDataFromCloudKitOnly(roomName: String, completion: @escaping (ARWorldMap?) -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error as? CKError {
                print("CloudKit query error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let record = records?.first,
                  let asset = record["mapAsset"] as? CKAsset,
                  let assetFileURL = asset.fileURL else {
                print("No valid record or asset for \(roomName).")
                completion(nil)
                return
            }
            
            do {
                let data = try Data(contentsOf: assetFileURL)
                if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    self.saveLocallyAfterCloudDownload(roomName: roomName, data: data, lastModified: Date())
                    completion(unarchivedMap)
                } else {
                    print("Failed to unarchive ARWorldMap from CloudKit data.")
                    completion(nil)
                }
            } catch {
                print("Error loading CloudKit asset: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    private func saveLocallyAfterCloudDownload(roomName: String, data: Data, lastModified: Date) {
        let filePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
        do {
            try data.write(to: filePath)
            DispatchQueue.main.async {
                if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                    self.savedWorlds[index].lastModified = lastModified
                } else {
                    self.savedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                }
                self.saveWorldList()
                print("World \(roomName) saved locally after CloudKit sync.")
            }
        } catch {
            print("Error saving locally after CloudKit sync: \(error.localizedDescription)")
        }
    }
    
    func getAnchorNames(for worldName: String, completion: @escaping ([String]) -> Void) {
        guard let world = savedWorlds.first(where: { $0.name == worldName }) else {
            print("No saved world found with the name: \(worldName)")
            completion([])
            return
        }

        if !FileManager.default.fileExists(atPath: world.filePath.path) {
            print("File not found for \(worldName). Trying CloudKit...")
            loadWorldMapDataFromCloudKitOnly(roomName: worldName) { cloudMap in
                guard let cloudMap = cloudMap else {
                    completion([])
                    return
                }
                let anchorNames = cloudMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
                completion(anchorNames)
            }
        } else {
            do {
                let data = try Data(contentsOf: world.filePath)
                if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    let anchorNames = unarchivedMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
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
}
