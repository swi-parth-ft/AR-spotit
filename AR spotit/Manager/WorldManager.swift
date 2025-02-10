import ARKit
import CloudKit

class WorldManager: ObservableObject {
    static let shared = WorldManager()

    private lazy var iCloudManager: iCloudManager = {
        return it_s_here_.iCloudManager(worldManager: self)
        }()
    @Published var savedWorlds: [WorldModel] = []
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
    @Published var isWorldLoaded = false
    @Published var isShowingARGuide = false

    var currentWorldName: String = ""
    @Published var is3DArrowActive = false

  //  @Published var selectedWorld: WorldModel? = nil // Added property

    init() {

    }
    
    func saveWorldMap(for roomName: String, sceneView: ARSCNView) {
        sceneView.session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self = self, let map = worldMap else { return }

            let timestamp = Date()
            var isNew = true
            if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                // If the world already exists, we'll preserve the old snapshot from its container
                isNew = false
                self.savedWorlds[index].lastModified = timestamp
            } else {
                self.savedWorlds.append(WorldModel(name: roomName, lastModified: timestamp))
            }

            let filePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
            sceneView.session.pause()
            
            // --- (A) Decide what snapshotData to embed ---
            var snapshotData: Data? = nil

            if isNew {
                // (A1) If it's a new world, capture a fresh snapshot:
                if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator,
                   let snapshotImage = coordinator.capturePointCloudSnapshotOffscreenClone() {
                    
                    // Still save a separate .png for your WorldsView
                    let imageURL = WorldModel.appSupportDirectory
                        .appendingPathComponent("\(roomName)_snapshot.png")
                    try? snapshotImage.pngData()?.write(to: imageURL)
                    
                    snapshotData = snapshotImage.pngData()
                }
            } else {
                // (A2) If it's an existing world, preserve the old snapshot from the container
                if FileManager.default.fileExists(atPath: filePath.path) {
                    do {
                        let oldData = try Data(contentsOf: filePath)
                        if let oldContainer = try NSKeyedUnarchiver
                            .unarchivedObject(ofClass: ARWorldMapContainer.self, from: oldData) {
                            snapshotData = oldContainer.imageData
                        }
                    } catch {
                        print("Failed to read old container for existing world: \(error)")
                    }
                }
            }

            // --- (B) Build and archive the container ---
            do {
                let container = ARWorldMapContainer(map: map, imageData: snapshotData)
                let containerData = try NSKeyedArchiver.archivedData(
                    withRootObject: container,
                    requiringSecureCoding: false
                )
                
                try containerData.write(to: filePath)
                self.saveWorldList()
                
                // (C) Upload to iCloud
                self.iCloudManager.uploadWorldMap(roomName: roomName, data: containerData, lastModified: timestamp) {
                    print("Synced \(roomName) to CloudKit.")
                }
            } catch {
                print("Error saving container for \(roomName): \(error)")
            }
        }
    }
    
//    func saveWorldMap(for roomName: String, sceneView: ARSCNView) {
//        sceneView.session.getCurrentWorldMap { [weak self] worldMap, error in
//            guard let self = self, let map = worldMap else {
//                print("Error saving world map: \(error?.localizedDescription ?? "No world map available.")")
//                return
//            }
//            
//            let timestamp = Date()
//            var isNew = true
//            if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
//                isNew = false
//                self.savedWorlds[index].lastModified = timestamp
//            } else {
//                isNew = true
//                self.savedWorlds.append(WorldModel(name: roomName, lastModified: timestamp))
//            }
//            sceneView.session.pause()
//            reload.toggle()
//            let world = self.savedWorlds.first { $0.name == roomName }!
//            
//            do {
//                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
//                let filePath = world.filePath
//                try data.write(to: filePath)
//                self.saveWorldList()
//                
//                print("World map for \(roomName) saved locally at: \(filePath.path)")
//                
//                if isNew {
//                    if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
//                        if let snapshotImage = coordinator.capturePointCloudSnapshotOffscreenClone() {
//                            
//                            // Generate a filename for the PNG
//                            let imageFilename = "\(roomName)_snapshot.png"
//                            let imageFileURL = WorldModel.appSupportDirectory.appendingPathComponent(imageFilename)
//                            
//                            do {
//                                try snapshotImage.pngData()?.write(to: imageFileURL)
//                                print("Saved snapshot image for \(roomName) at \(imageFileURL.path)")
//                            } catch {
//                                print("Error saving snapshot PNG: \(error.localizedDescription)")
//                            }
//                        } else {
//                            print("Failed to capture mesh snapshot for \(roomName).")
//                        }
//                    }
//                }
//                iCloudManager.uploadWorldMap(roomName: roomName, data: data, lastModified: timestamp) {
//                    print("Sync to CloudKit complete for \(roomName).")
//                }
//            } catch {
//                print("Error saving world map locally: \(error.localizedDescription)")
//            }
//        }
//    }
    
    func loadWorldMap(for roomName: String, sceneView: ARSCNView) {
        
        // isRelocalizationComplete = false
        print("Attempting to load world map for room: \(roomName)")
        
        guard let world = savedWorlds.first(where: { $0.name == roomName }) else {
            print("No saved world found with the name: \(roomName)")
            isShowingARGuide = true

            return
        }
        
        let filePath = world.filePath
        print(filePath)
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("File not found at path: \(filePath.path). Trying CloudKit...")
            loadFromCloudKit(roomName: roomName, sceneView: sceneView)
//            iCloudManager.loadWorldMap(roomName: roomName, data: data, lastModified: timestamp) {
//                print("Sync to CloudKit complete for \(roomName).")
//            }
            return
        }
        
        do {
            let data = try Data(contentsOf: filePath)
//            let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            
            // Unarchive the container instead of just ARWorldMap
            guard let container = NSKeyedUnarchiver.unarchiveObject(with: data) as? ARWorldMapContainer else {
                print("Failed to unarchive ARWorldMapContainer using legacy method.")
                return
            } 
               
                
                // Grab the ARWorldMap
                let worldMap = container.map
            
            sceneView.session.pause()
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.initialWorldMap = worldMap
            configuration.planeDetection = [.horizontal, .vertical]
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                
                configuration.sceneReconstruction = .mesh // Ensure LiDAR reconstruction
            }
            
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
            isWorldLoaded = true
            isShowingARGuide = true
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
            
            indexWorlds()

            //  print("World list saved at: \(fileURL.path)")
        } catch {
            print("Error saving world list: \(error.localizedDescription)")
        }
    }
    
    func loadSavedWorlds(completion: @escaping () -> Void) {
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
                
                       self.indexWorlds()

                print("Saved worlds loaded: \(self.savedWorlds.map { $0.name })")
            }
        } catch {
            DispatchQueue.main.async {
                self.savedWorlds = []
                print("No saved world list found or failed to decode: \(error.localizedDescription)")
            }
        }
        
        // Proceed to fetch from CloudKit
        fetchWorldNamesFromCloudKit {
            print("Data synced with CloudKit.")
            
            // Initialize DispatchGroup to track multiple async tasks
            let dispatchGroup = DispatchGroup()
            
            for world in self.savedWorlds {
                // Fetch anchor names
                dispatchGroup.enter()
                self.getAnchorNames(for: world.name) { anchorNames in
                    DispatchQueue.main.async {
                        self.cachedAnchorNames[world.name] = anchorNames
                    }
                    dispatchGroup.leave()
                }
                
                // Check and load missing world maps from CloudKit
                if !FileManager.default.fileExists(atPath: world.filePath.path) {
                    print("Fetching missing data for world: \(world.name)")
                    dispatchGroup.enter()
                    self.iCloudManager.loadWorldMap(roomName: world.name) { data, arMap in
                         // Previously you had: { _ in print("Fetched and saved locally.") }

                         // Now we get BOTH the container Data and the ARWorldMap
                         if let data = data {
                             // Write that container to disk + restore snapshot
                             self.saveLocallyAfterCloudDownload(roomName: world.name, data: data, lastModified: world.lastModified)
                         }
                         
                         // If you need the map for anchor reading, you can do that too
                         // e.g. if let arMap = arMap { ... }
                         
                         print("Fetched container for \(world.name) and saved locally.")
                         dispatchGroup.leave()
                     }
                }
            }
            
            // Notify once all async tasks are completed
            dispatchGroup.notify(queue: .main) {
                completion()
            }
        }
    }
    
//    func loadSavedWorlds() {
//        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
//        do {
//            let data = try Data(contentsOf: fileURL)
//            let decodedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
//            
//            // Deduplicate based on world name
//            let uniqueWorlds = Array(
//                Dictionary(grouping: decodedWorlds, by: { $0.name })
//                    .compactMap { $0.value.first }
//            )
//            
//            DispatchQueue.main.async {
//                self.savedWorlds = uniqueWorlds
//                print("Saved worlds loaded: \(self.savedWorlds.map { $0.name })")
//            }
//        } catch {
//            DispatchQueue.main.async {
//                self.savedWorlds = []
//                print("No saved world list found or failed to decode: \(error.localizedDescription)")
//            }
//        }
//        
//        
//             fetchWorldNamesFromCloudKit {
//                 print("Data synced with CloudKit.")
//     
//                 for world in self.savedWorlds {
//                     self.getAnchorNames(for: world.name) { anchorNames in
//                         DispatchQueue.main.async {
//                             self.cachedAnchorNames[world.name] = anchorNames
//                         }
//                     }
//     
//                     if !FileManager.default.fileExists(atPath: world.filePath.path) {
//                         print("Fetching missing data for world: \(world.name)")
//     
//                         self.iCloudManager.loadWorldMap(roomName: world.name) { _ in
//                             print("Fetched and saved \(world.name) locally.")
//                         }
//                     }
//                 }
//             }
//    }
    
    func getAnchorNames(for worldName: String, completion: @escaping ([String]) -> Void) {

        
        guard let world = savedWorlds.first(where: { $0.name == worldName }) else {
            print("No saved world found with the name: \(worldName)")
            completion([])
            return
        }
        
        if !FileManager.default.fileExists(atPath: world.filePath.path) {
            print("File not found for \(worldName). Trying CloudKit...")
            // FIX: Use the 2-argument callback now
                   iCloudManager.loadWorldMap(roomName: worldName) { data, arMap in
                       guard let arMap = arMap else {
                           completion([])
                           return
                       }
                       let anchorNames = arMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
                       completion(anchorNames)
                   }
        } else {
            do {
                let data = try Data(contentsOf: world.filePath)
                if let container = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: ARWorldMapContainer.self,
                    from: data
                ) {
                    let unarchivedMap = container.map
                    let anchorNames = unarchivedMap.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
                    completion(anchorNames)
                } else {
                    print("Failed to unarchive ARWorldMapContainer for \(worldName).")
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
                
                let uniqueIdentifier = "com.parthant.AR-spotit.\(world.name)"
                   CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [uniqueIdentifier]) { error in
                       if let error = error {
                           print("Error deleting world from Spotlight index: \(error.localizedDescription)")
                       } else {
                           print("Successfully removed \(roomName) from Spotlight index.")
                       }
                   }
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
      //  deleteWorldFromCloudKit(roomName: roomName) {_ in }
        iCloudManager.deleteWorld(roomName: roomName) { error in
            if let error = error {
                print("Error deleting world from CloudKit: \(error.localizedDescription)")
            } else {
                print("Deleted world \(roomName) from CloudKit.")
            }
        }
        
        
    }
    
    func saveLocallyAfterCloudDownload(roomName: String, data: Data, lastModified: Date) {
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
        
        do {
              if let container = try NSKeyedUnarchiver
                  .unarchivedObject(ofClass: ARWorldMapContainer.self, from: data),
                 let snapshotData = container.imageData {
                  
                  let snapshotURL = WorldModel.appSupportDirectory
                      .appendingPathComponent("\(roomName)_snapshot.png")
                  try snapshotData.write(to: snapshotURL)
                  print("✅ Restored snapshot for \(roomName) from iCloud at: \(snapshotURL.path)")
              }
          } catch {
              print("❌ Could not restore snapshot: \(error)")
          }
    }
    
    
    func shareWorld(currentRoomName: String) {
        guard let world = savedWorlds.first(where: { $0.name == currentRoomName }) else {
            print("No world found with name \(currentRoomName).")
            return
        }

        let sourceFilePath = world.filePath
        guard FileManager.default.fileExists(atPath: sourceFilePath.path) else {
            print("World map file not found.")
            return
        }

        // Move file to a shareable location
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent("\(currentRoomName)_worldMap.worldmap")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceFilePath, to: destinationURL)
            print("File ready for sharing at: \(destinationURL)")

            // Present the share sheet
            let activityController = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                DispatchQueue.main.async {
                    if let presentedVC = rootViewController.presentedViewController {
                        presentedVC.dismiss(animated: false) {
                            rootViewController.present(activityController, animated: true, completion: nil)
                        }
                    } else {
                        rootViewController.present(activityController, animated: true, completion: nil)
                    }
                }
            }
        } catch {
            print("Error preparing file for sharing: \(error.localizedDescription)")
        }
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
            
//            // Fetch from iCloud if local data is unavailable
//            iCloudManager.loadWorldMap(roomName: currentName) { [weak self] map in
//                guard let self = self, let map = map else {
//                    print("❌ Failed to fetch \(currentName) from iCloud.")
//                    completion?()
//                    return
//                }
//                
//                do {
//                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
//                    self.renameAndSaveWorld(data: data, currentName: currentName, newName: newName, completion: completion)
//                } catch {
//                    print("❌ Error archiving ARWorldMap: \(error.localizedDescription)")
//                    completion?()
//                }
//            }
        }
        
        // 3) If not local, load from iCloud
        iCloudManager.loadWorldMap(roomName: currentName) { [weak self] data, arMap in
            guard let self = self else { return }
            
            // If no data found, fail
            guard let data = data else {
                print("❌ Failed to fetch \(currentName) from iCloud.")
                completion?()
                return
            }
            
            // Now we have the actual container data from CloudKit
            self.renameAndSaveWorld(data: data, currentName: currentName, newName: newName, completion: completion)
        }
    }
    
    private func renameAndSaveWorld(data: Data, currentName: String, newName: String, completion: (() -> Void)?) {
        saveImportedWorld(data: data, worldName: newName)
        // 2) Rename the snapshot file, if it exists
           let oldSnapshotURL = WorldModel.appSupportDirectory
               .appendingPathComponent("\(currentName)_snapshot.png")
           let newSnapshotURL = WorldModel.appSupportDirectory
               .appendingPathComponent("\(newName)_snapshot.png")
           
           if FileManager.default.fileExists(atPath: oldSnapshotURL.path) {
               do {
                   try FileManager.default.moveItem(at: oldSnapshotURL, to: newSnapshotURL)
                   print("✅ Snapshot renamed from \(currentName) to \(newName).")
               } catch {
                   print("❌ Error renaming snapshot: \(error.localizedDescription)")
               }
           } else {
               print("No existing snapshot found for \(currentName).")
           }
        
        deleteWorld(roomName: currentName) {
            print("✅ Renamed \(currentName) to \(newName) successfully.")
            
            
            DispatchQueue.main.async {
                self.reload.toggle()
                
            }
            
            completion?()
        }
    }
    
    func importWorldFromURL(_ url: URL) {
        DispatchQueue.main.async {
            self.importWorldURL = url
            self.tempWorldName = url.deletingPathExtension().lastPathComponent // Default name
            self.isImportingWorld = true
        }
        // Store the URL and show the sheet for naming
       
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
        
        // 2) **Unarchive the container** to extract snapshotData, then write as PNG:
        do {
            if let container = try NSKeyedUnarchiver
                .unarchivedObject(ofClass: ARWorldMapContainer.self, from: data),
               let snapshotData = container.imageData {
                
                let snapshotURL = WorldModel.appSupportDirectory
                    .appendingPathComponent("\(worldName)_snapshot.png")
                try snapshotData.write(to: snapshotURL)
                print("✅ Restored snapshot for \(worldName) at: \(snapshotURL.path)")
            }
        } catch {
            print("❌ Could not restore snapshot for \(worldName): \(error)")
        }
        
        iCloudManager.uploadWorldMap(roomName: worldName, data: data, lastModified: timestamp) {
            print("Sync to CloudKit complete for \(worldName).")
        }
    }
}

//MARK: iCloud CRUD
extension WorldManager {

    func fetchWorldNamesFromCloudKit(completion: @escaping () -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        privateDB.fetch(
            withQuery: query,
            inZoneWith: nil,
            desiredKeys: ["roomName", "lastModified"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?), any Error>) in
            
            switch result {
            case .success(let (matchResults, _)):
                var fetchedWorlds: [WorldModel] = []
                
                // Process the array of matchResults
                for (recordID, recordResult) in matchResults {
                    switch recordResult {
                    case .success(let record):
                        let roomName = record["roomName"] as? String ?? "Unnamed"
                        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
                        print("Fetched record with roomName: \(roomName)")
                        
                        // Check if local data is older than CloudKit data
                        if let localWorld = self.savedWorlds.first(where: { $0.name == roomName }),
                           lastModified > localWorld.lastModified {
                            print("Cloud data for \(roomName) is newer. Downloading...")
                            self.iCloudManager.loadWorldMap(roomName: roomName) { _, _ in }
                        } else if !self.savedWorlds.contains(where: { $0.name == roomName }) {
                            // Add new world from CloudKit if it doesn't exist locally
                            fetchedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                        }
                    case .failure(let error):
                        print("Error fetching record \(recordID): \(error.localizedDescription)")
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
    
//    func fetchWorldNamesFromCloudKit(completion: @escaping () -> Void) {
//        let privateDB = CKContainer.default().privateCloudDatabase
//        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
//        
//        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["roomName", "lastModified"], resultsLimit: CKQueryOperation.maximumResults) { (result: Result<([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?), Error>) in
//            switch result {
//            case .success(let (matchedResults, _)):
//                var fetchedWorlds: [WorldModel] = []
//                
//                for (_, recordResult) in matchedResults {
//                    switch recordResult {
//                    case .success(let record):
//                        let roomName = record["roomName"] as? String ?? "Unnamed"
//                        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
//                        print("Fetched record with roomName: \(roomName)")
//                        
//                        
//                        
//                        // Check if local data is older than CloudKit data
//                        if let localWorld = self.savedWorlds.first(where: { $0.name == roomName }),
//                           lastModified > localWorld.lastModified {
//                            print("Cloud data for \(roomName) is newer. Downloading...")
//                            self.iCloudManager.loadWorldMap(roomName: roomName) { _ in }
//                        } else if !self.savedWorlds.contains(where: { $0.name == roomName }) {
//                            // Add new world from CloudKit if it doesn't exist locally
//                            fetchedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
//                        }
//                    case .failure(let error):
//                        print("Error fetching record: \(error.localizedDescription)")
//                    }
//                }
//                
//                DispatchQueue.main.async {
//                    // Avoid duplicates with savedWorlds
//                    self.savedWorlds.append(contentsOf: fetchedWorlds.filter { fetchedWorld in
//                        !self.savedWorlds.contains(where: { $0.name == fetchedWorld.name })
//                    })
//                    self.saveWorldList()
//                    completion()
//                }
//                
//            case .failure(let error):
//                print("Error fetching world names from CloudKit: \(error.localizedDescription)")
//                completion()
//            }
//        }
//    }
    
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
                
                // 1) Decode ARWorldMapContainer
                if let container = try NSKeyedUnarchiver
                    .unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                    
                    // 2) Extract the actual ARWorldMap from the container
                    let unarchivedMap = container.map
                    
                    DispatchQueue.main.async {
                        // 3) Save to local + run AR session
                        self?.saveLocallyAfterCloudDownload(roomName: roomName, data: data, lastModified: Date())
                        
                        sceneView.session.pause()
                        let configuration = ARWorldTrackingConfiguration()
                        configuration.initialWorldMap = unarchivedMap
                        configuration.planeDetection = [.horizontal, .vertical]
                        configuration.sceneReconstruction = .mesh
                        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                        
                        print("World map for \(roomName) loaded from CloudKit (container).")
                    }
                    
                } else {
                    print("❌ Failed to unarchive ARWorldMapContainer from CloudKit.")
                }
            } catch {
                print("❌ Error reading CloudKit asset: \(error.localizedDescription)")
            }
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

extension WorldManager {
    func checkAndSyncIfNewer(for roomName: String, completion: @escaping () -> Void) {
        // Make sure we know about the local world
        guard let localWorld = savedWorlds.first(where: { $0.name == roomName }) else {
            // If not found locally, there's nothing to compare—just finish
            completion()
            return
        }
        
        // Fetch the iCloud lastModified
        iCloudManager.fetchLastModified(for: roomName) { cloudLastModified in
            // If no record or date in iCloud, or if iCloud date is not newer, we do nothing
            guard let cloudLastModified = cloudLastModified,
                  cloudLastModified > localWorld.lastModified else {
                completion()
                return
            }
            
            print("⏫ Found newer data in iCloud for \(roomName). Downloading...")
            
            // Download the new data from iCloud
            self.iCloudManager.loadWorldMap(roomName: roomName) { data, arMap in
                if let data = data {
                    self.saveLocallyAfterCloudDownload(roomName: roomName,
                                                       data: data,
                                                       lastModified: cloudLastModified)
                }
                completion()
            }
        }
    }
}


extension WorldManager {
    func loadSavedWorldsAsync() async {
        await withCheckedContinuation { continuation in
            self.loadSavedWorlds {
                continuation.resume()
            }
        }
    }
}


import CoreSpotlight
import MobileCoreServices
import SwiftUI

extension WorldManager {
    
    func indexWorlds() {
        let searchableItems = savedWorlds.map { createSearchableItem(for: $0) }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Successfully indexed \(searchableItems.count) worlds")
            }
        }
    }
    
    private func createSearchableItem(for world: WorldModel) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributeSet.title = world.name
        attributeSet.contentDescription = "Explore the \(world.name) in it's here."
        // Optionally, add keywords, thumbnail, etc.
        // Example: attributeSet.keywords = ["AR", "World", "Spotit"]
        if let snapshotImage = getSnapshotImage(for: world) {
            attributeSet.thumbnailData = snapshotImage.pngData()
        }
        
        let uniqueIdentifier = "com.parthant.AR-spotit.\(world.name)"
        let domainIdentifier = "com.parthant.AR-spotit"
        
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    
    private func getSnapshotImage(for world: WorldModel) -> UIImage? {
        let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(world.name)_snapshot.png")
        if FileManager.default.fileExists(atPath: snapshotPath.path),
           let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
            return uiImage
        }
        return nil
    }
    
    
    func indexItems(anchors: [(anchorName: String, worldName: String)]) {
        let searchableItems = anchors.map { createSearchableAnchor(anchorName: $0.anchorName, worldName: $0.worldName) }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Successfully indexed \(searchableItems.count) items")
            }
        }
    }
    
    private func createSearchableAnchor(anchorName: String, worldName: String) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributeSet.title = anchorName
        attributeSet.contentDescription = "Search for \(anchorName) in world \(worldName)"
        
        // Incorporate both worldName and anchorName in the unique identifier.
        let uniqueIdentifier = "item.com.parthant.AR-spotit.\(worldName).\(anchorName)"
        let domainIdentifier = "com.parthant.AR-spotit"
        
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    
    
    
//    func indexItems(anchors: [String]) {
//        let searchableItems = anchors.map { createSearchableAnchors(for: $0) }
//        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
//            if let error = error {
//                print("Indexing error: \(error.localizedDescription)")
//            } else {
//                print("Successfully indexed \(searchableItems.count) items")
//            }
//        }
//    }
//    
//    private func createSearchableAnchors(for item: String) -> CSSearchableItem {
//        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
//        attributeSet.title = item
//        attributeSet.contentDescription = "Search for \(item) in it's here."
//        
//        // Optionally, add keywords, thumbnail, etc.
//        // Example: attributeSet.keywords = ["AR", "World", "Spotit"]
//       
//        
//        let uniqueIdentifier = "item.com.parthant.AR-spotit.\(item)"
//        let domainIdentifier = "com.parthant.AR-spotit"
//        
//        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
//    }
}



extension WorldManager {
    
    
    func inspectLocalArchive(for roomName: String) {
        let filePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
        do {
            let data = try Data(contentsOf: filePath)
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            // Decode the root object without casting it, then print its class description.
            if let rootObject = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) {
                print("Local archive root object class: \(type(of: rootObject))")
            } else {
                print("Failed to decode local archive root object")
            }
            unarchiver.finishDecoding()
        } catch {
            print("Error inspecting local archive: \(error.localizedDescription)")
        }
    }
    
    
    func shareWorldViaCloudKit(roomName: String) {
        it_s_here_.iCloudManager(worldManager: self).createShareLink(for: roomName) { shareURL in
            guard let shareURL = shareURL else {
                print("Failed to create share URL.")
                return
            }
            
            // Present a share sheet with the share URL.
            DispatchQueue.main.async {
                let activityController = UIActivityViewController(activityItems: [shareURL], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    if let presentedVC = rootViewController.presentedViewController {
                        presentedVC.dismiss(animated: false) {
                            rootViewController.present(activityController, animated: true, completion: nil)
                        }
                    } else {
                        rootViewController.present(activityController, animated: true, completion: nil)
                    }
                }
            }
        }
    }
}


extension WorldManager {
    func duplicateSharedWorld(from sharedRecord: CKRecord, using container: ARWorldMapContainer, archiveData: Data) {
        // Determine a new world name by appending " Copy"
        let originalName = sharedRecord["roomName"] as? String ?? "Unnamed"
        let newName = originalName + " Copy"
        
        // Get your custom zone from your iCloudManager
        let customZoneID = it_s_here_.iCloudManager(worldManager: self).customZoneID
        let newRecordID = CKRecord.ID(recordName: "\(newName)_Record", zoneID: customZoneID)
        
        // Create a new CKRecord of the same type
        let newRecord = CKRecord(recordType: sharedRecord.recordType, recordID: newRecordID)
        newRecord["roomName"] = newName as CKRecordValue
        newRecord["lastModified"] = Date() as CKRecordValue
        
        do {
            // **Set the class name mapping before archiving.**
            NSKeyedArchiver.setClassName("ARWorldMapContainer", for: ARWorldMapContainer.self)
            // Archive using the same settings as your local save
            let newArchiveData = try NSKeyedArchiver.archivedData(withRootObject: container, requiringSecureCoding: false)
            
            // Write the archive data to the same file path/extension used for local saves.
            let localFilePath = WorldModel.appSupportDirectory.appendingPathComponent("\(newName)_worldMap")
            try newArchiveData.write(to: localFilePath)
            
            // Create a CKAsset from that file.
            let asset = CKAsset(fileURL: localFilePath)
            newRecord["mapAsset"] = asset
            
            // Save the new record to your private CloudKit database.
            let privateDB = CKContainer.default().privateCloudDatabase
            privateDB.save(newRecord) { record, error in
                if let error = error {
                    print("Error saving duplicated record: \(error.localizedDescription)")
                } else if let record = record {
                    print("Successfully duplicated shared world: \(record.recordID.recordName)")
                    DispatchQueue.main.async {
                        self.savedWorlds.append(WorldModel(name: newName, lastModified: Date()))
                        self.saveWorldList()
                    }
                }
            }
        } catch {
            print("Error writing archive data for duplicate: \(error.localizedDescription)")
        }
    }}
