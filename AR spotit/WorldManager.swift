import ARKit
import CloudKit

class WorldManager: ObservableObject {
    @Published var savedWorlds: [WorldModel] = [] // List of saved worlds
    
    private let recordType = "ARWorldMapRecord"
    var anchorMapping: [String: ARAnchor] = [:]
    @Published var cachedAnchorNames: [String: [String]] = [:]
    @Published var isShowingAll = true
    @Published var isRelocalizationComplete: Bool = false
    @Published var scanningZones: [String: simd_float4x4] = [:]
    @Published var scannedZones: Set<String> = []
    @Published var isAddingAnchor = false
    @Published var deletedAnchors: [ARAnchor] = []
    
    @Published var isImportingWorld: Bool = false
    @Published var importWorldURL: URL?
    @Published var tempWorldName = ""
    @Published var reload = false
    
    init() {
        //        deleteAllRecords { error in
        //            if let error = error {
        //                print("Error deleting all records: \(error.localizedDescription)")
        //            } else {
        //                print("Successfully deleted all records from CloudKit.")
        //            }
        //        }
        loadSavedWorlds()
        
        fetchWorldNamesFromCloudKit {
            print("Data synced with CloudKit.")
            
            for world in self.savedWorlds {
                self.getAnchorNames(for: world.name) { anchorNames in
                    DispatchQueue.main.async {
                        self.cachedAnchorNames[world.name] = anchorNames
                    }
                }
                
                if !FileManager.default.fileExists(atPath: world.filePath.path) {
                    print("Fetching missing data for world: \(world.name)")
                    self.loadWorldMapDataFromCloudKitOnly(roomName: world.name) { _ in
                        print("Fetched and saved \(world.name) locally.")
                    }
                }
            }
        }
    }
    
    

    
    func deleteAllRecords(completion: @escaping (Error?) -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let recordTypes = ["ARWorldMapRecord", "WorldListRecord"] // Add all your record types here
        
        let dispatchGroup = DispatchGroup()
        var finalError: Error?
        
        for recordType in recordTypes {
            dispatchGroup.enter()
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            
            privateDB.fetch(
                withQuery: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
                
                switch result {
                case .success(let (matchResults, _)):
                    let recordIDs = matchResults.compactMap { (recordID, result) -> CKRecord.ID? in
                        switch result {
                        case .success:
                            return recordID
                        case .failure(let error):
                            print("Error fetching record \(recordID): \(error.localizedDescription)")
                            return nil
                        }
                    }
                    
                    guard !recordIDs.isEmpty else {
                        print("No records found for \(recordType).")
                        dispatchGroup.leave()
                        return
                    }
                    
                    let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                    deleteOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("Successfully deleted all records of type \(recordType).")
                        case .failure(let error):
                            print("Error deleting records for \(recordType): \(error.localizedDescription)")
                            finalError = error
                        }
                        dispatchGroup.leave()
                    }
                    
                    privateDB.add(deleteOperation)
                    
                case .failure(let error):
                    print("Error fetching records for \(recordType): \(error.localizedDescription)")
                    finalError = error
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(finalError)
        }
    }
    
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
    
    func loadWorldMap(for roomName: String, sceneView: ARSCNView) {
        
        // isRelocalizationComplete = false
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
            
            if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                coordinator.worldIsLoaded = false
                coordinator.isLoading = true
            }
            
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                
                //                        coordinator.placedGuideAnchors.removeAll()
                //                        coordinator.processedPlaneAnchorIDs.removeAll()  // Cl
                coordinator.worldIsLoaded = true
                print("World loaded. Ready to add new guide anchors.")
            }
            
            print("World map for \(roomName) loaded successfully.")
        } catch {
            print("Error loading ARWorldMap for \(roomName): \(error.localizedDescription)")
        }
    }
    
    func saveWorldList() {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try JSONEncoder().encode(savedWorlds)
            try data.write(to: fileURL)
            //  print("World list saved at: \(fileURL.path)")
        } catch {
            print("Error saving world list: \(error.localizedDescription)")
        }
    }
    
    private func loadSavedWorlds() {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
            
            // Deduplicate based on world name
            let uniqueWorlds = Array(
                Dictionary(grouping: decodedWorlds, by: { $0.name })
                    .compactMap { $0.value.first }
            )
            
            DispatchQueue.main.async {
                self.savedWorlds = uniqueWorlds
                print("Saved worlds loaded: \(self.savedWorlds.map { $0.name })")
            }
        } catch {
            DispatchQueue.main.async {
                self.savedWorlds = []
                print("No saved world list found or failed to decode: \(error.localizedDescription)")
            }
        }
    }
    
    func getAnchorNames(for worldName: String, completion: @escaping ([String]) -> Void) {
        
        if worldName == "Bedroom" {
            print("Deleting 'Bedroom' world.")
            deleteWorld(roomName: worldName) {
                print("'Bedroom' world deleted successfully.")
                completion([]) // Return an empty array since the world was deleted
            }
            return
        }
        
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
        
    func deleteWorld(roomName: String, completion: (() -> Void)? = nil) {
        // Find the world in the savedWorlds array
        guard let index = savedWorlds.firstIndex(where: { $0.name == roomName }) else {
            print("No world found with name \(roomName)")
            completion?()
            return
        }
        
        let world = savedWorlds[index]
        let filePath = world.filePath
        
        // Remove local file if it exists
        if FileManager.default.fileExists(atPath: filePath.path) {
            do {
                try FileManager.default.removeItem(at: filePath)
                print("Local world file for \(roomName) deleted.")
                DispatchQueue.main.async {
                    self.cachedAnchorNames[roomName] = nil // Clear cache for the deleted world
                    completion?()
                }
            } catch {
                print("Error deleting local world file: \(error.localizedDescription)")
            }
        }
        
        // Remove world from the saved list and update JSON file
        savedWorlds.remove(at: index)
        saveWorldList()
        deleteWorldFromCloudKit(roomName: roomName) {_ in }
        
        
    }
    
}

//MARK: Rename and Import
extension WorldManager {
    func renameWorld(currentName: String, newName: String, completion: (() -> Void)? = nil) {
        // Ensure new name is not empty
        guard !newName.isEmpty else {
            print("❌ New name cannot be empty.")
            completion?()
            return
        }
        
        // Check if the world with currentName exists
        guard let world = savedWorlds.first(where: { $0.name == currentName }) else {
            print("❌ No world found with name \(currentName).")
            completion?()
            return
        }
        
        let oldFilePath = world.filePath
        
        // Try to load world map data from local storage first
        do {
            let data = try Data(contentsOf: oldFilePath)
            renameAndSaveWorld(data: data, currentName: currentName, newName: newName, completion: completion)
            completion?()
            return
        } catch {
            print("⚠️ Local file not found for \(currentName). Trying to fetch from iCloud...")
            
            // Fetch from iCloud if local data is unavailable
            loadWorldMapDataFromCloudKitOnly(roomName: currentName) { [weak self] map in
                guard let self = self, let map = map else {
                    print("❌ Failed to fetch \(currentName) from iCloud.")
                    completion?()
                    return
                }
                
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    self.renameAndSaveWorld(data: data, currentName: currentName, newName: newName, completion: completion)
                } catch {
                    print("❌ Error archiving ARWorldMap: \(error.localizedDescription)")
                    completion?()
                }
            }
        }
    }
    
    private func renameAndSaveWorld(data: Data, currentName: String, newName: String, completion: (() -> Void)?) {
        saveImportedWorld(data: data, worldName: newName)
        
        
        deleteWorld(roomName: currentName) {
            print("✅ Renamed \(currentName) to \(newName) successfully.")
            
            
            DispatchQueue.main.async {
                self.reload.toggle()
                
            }
            
            completion?()
        }
    }
    
    func importWorldFromURL(_ url: URL) {
        // Store the URL and show the sheet for naming
        self.importWorldURL = url
        self.tempWorldName = url.deletingPathExtension().lastPathComponent // Default name
        self.isImportingWorld = true
    }
    
    func saveImportedWorld(data: Data, worldName: String) {
        let timestamp = Date()
        
        // Check if the world already exists
        if let index = self.savedWorlds.firstIndex(where: { $0.name == worldName }) {
            self.savedWorlds[index].lastModified = timestamp
        } else {
            self.savedWorlds.append(WorldModel(name: worldName, lastModified: timestamp))
        }
        
        // Save to local file
        guard let newWorld = self.savedWorlds.first(where: { $0.name == worldName }) else {
            print("Failed to find the newly created world.")
            return
        }
        
        do {
            try data.write(to: newWorld.filePath)
            self.saveWorldList()
            print("✅ Imported world saved as \(worldName).")
        } catch {
            print("❌ Error saving imported world: \(error.localizedDescription)")
        }
        
        // Optionally sync to CloudKit
        self.uploadARWorldMapToCloudKit(roomName: worldName, data: data, lastModified: timestamp) {
            print("☁️ Synced \(worldName) to CloudKit.")
        }
    }
}

//MARK: iCloud CRUD
extension WorldManager {
    func uploadARWorldMapToCloudKit(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(roomName)_tempWorldMap")
            do {
                try data.write(to: tempURL)
                let record = CKRecord(recordType: self.recordType)
                record["roomName"] = roomName as CKRecordValue
                record["mapAsset"] = CKAsset(fileURL: tempURL)
                record["lastModified"] = lastModified as CKRecordValue
                
                let privateDB = CKContainer.default().privateCloudDatabase
                privateDB.save(record) { savedRecord, error in
                    try? FileManager.default.removeItem(at: tempURL)
                    if let error = error {
                        print("Error uploading to CloudKit: \(error.localizedDescription)")
                    } else {
                        print("Uploaded \(roomName) to CloudKit.")
                    }
                    completion?()
                }
            } catch {
                print("Error writing temp file: \(error.localizedDescription)")
                completion?()
            }
        }
    }
    
    func fetchWorldNamesFromCloudKit(completion: @escaping () -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["roomName", "lastModified"], resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                var fetchedWorlds: [WorldModel] = []
                
                for (_, recordResult) in matchedResults {
                    switch recordResult {
                    case .success(let record):
                        let roomName = record["roomName"] as? String ?? "Unnamed"
                        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
                        print("Fetched record with roomName: \(roomName)")
                        
                        
                        
                        // Check if local data is older than CloudKit data
                        if let localWorld = self.savedWorlds.first(where: { $0.name == roomName }),
                           lastModified > localWorld.lastModified {
                            print("Cloud data for \(roomName) is newer. Downloading...")
                            self.loadWorldMapDataFromCloudKitOnly(roomName: roomName) { _ in }
                        } else if !self.savedWorlds.contains(where: { $0.name == roomName }) {
                            // Add new world from CloudKit if it doesn't exist locally
                            fetchedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                        }
                    case .failure(let error):
                        print("Error fetching record: \(error.localizedDescription)")
                    }
                }
                
                DispatchQueue.main.async {
                    // Avoid duplicates with savedWorlds
                    self.savedWorlds.append(contentsOf: fetchedWorlds.filter { fetchedWorld in
                        !self.savedWorlds.contains(where: { $0.name == fetchedWorld.name })
                    })
                    self.saveWorldList()
                    completion()
                }
                
            case .failure(let error):
                print("Error fetching world names from CloudKit: \(error.localizedDescription)")
                completion()
            }
        }
    }
    
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
    
    func deleteWorldFromCloudKit(roomName: String, completion: @escaping (Error?) -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: "ARWorldMapRecord", predicate: predicate)
        print("Executing query for \(roomName) with predicate: \(predicate)")
        let queryOperation = CKQueryOperation(query: query)
        
        // Array to store record IDs for deletion
        var recordsToDelete = [CKRecord.ID]()
        
        // Use recordMatchedBlock to process each fetched record and potential per-record errors
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(_):
                recordsToDelete.append(recordID)
            case .failure(let error):
                print("Error fetching record \(recordID): \(error.localizedDescription)")
                // Optionally handle individual record fetch errors here
            }
        }
        
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error performing query: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            if let records = records, !records.isEmpty {
                print("Found \(records.count) record(s) for \(roomName). Record IDs: \(records.map { $0.recordID })")
            } else {
                print("No records found for \(roomName).")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            switch result {
            case .success:
                guard !recordsToDelete.isEmpty else {
                    print("No CloudKit records found for \(roomName).")
                    completion(nil)
                    return
                }
                
                // Create modify operation to delete fetched records
                let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToDelete)
                modifyOperation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("World \(roomName) deleted from CloudKit.")
                        completion(nil)
                    case .failure(let error):
                        print("Error deleting records: \(error.localizedDescription)")
                        completion(error)
                    }
                }
                privateDB.add(modifyOperation)
                
            case .failure(let error):
                print("Query operation failed: \(error.localizedDescription)")
                completion(error)
            }
        }
        
        privateDB.add(queryOperation)
    }

}
