

////
//  WorldManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//
import Foundation
import ARKit
import CloudKit
import SwiftUI
import CoreSpotlight
import Drops


class WorldManager: ObservableObject {
    static let shared = WorldManager()
    
    lazy var iCloudManager: iCloudManager = {
        return it_s_here_.iCloudManager(worldManager: self)
    }()
    
    @Published var sharedRecordId: String = ""
    @Published var anchorRecordIDs: [String: String] = [:]
    var currentWorldRecord: CKRecord? // The shared world (root) record.
    @Published var currentRoomName: String = ""
    @Published var sharedZoneID: CKRecordZone.ID? = nil
    let recordType = "ARWorldMapRecord"
    var anchorMapping: [String: ARAnchor] = [:]
    var currentWorldName: String = ""
    @Published var isCollaborative: Bool = false
    @Published var sharedARWorldMap: ARWorldMap?
    @Published var sharedWorldName: String?
    @Published var sharedWorldsAnchors: [String] = []
    @Published var savedWorlds: [WorldModel] = []
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
    @Published var is3DArrowActive = false
    @Published var sharedLinks: [SharedLinkModel] = []
    @Published var shouldDeletePublicAnchors: Bool = false

    private let metadataRecordType = "WorldMetadata"

    init() { }
    func startCollaborativeSession(with sharedRecord: CKRecord, roomName: String) {
        DispatchQueue.main.async {

           self.currentWorldRecord = sharedRecord
            self.currentRoomName = roomName
            self.isCollaborative = true
        }
           print("Collaborative session started for room: \(roomName)")
       }
       
       /// Call this to exit collaborative mode if needed.
       func endCollaborativeSession() {
           self.currentWorldRecord = nil
           self.currentRoomName = ""
           self.isCollaborative = false
           print("Collaborative session ended.")
       }
    
    // MARK: - Save World Map
    func saveWorldMap(for roomName: String, sceneView: ARSCNView) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap else { return }
            let timestamp = Date()
            var isNew = true
            var publicName = ""
            if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                isNew = false
                self.savedWorlds[index].lastModified = timestamp
                publicName = self.savedWorlds[index].publicRecordName ?? ""
            } else {
                var newWorld = WorldModel(name: roomName, lastModified: timestamp)
                newWorld.cloudRecordID = UUID().uuidString
                self.savedWorlds.append(newWorld)
            }
            
            let filePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
            sceneView.session.pause()
            var snapshotData: Data? = nil
            
            if isNew {
                if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator,
                   let snapshotImage = coordinator.capturePointCloudSnapshotOffscreenClone() {
                    let imageURL = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_snapshot.png")
                    try? snapshotImage.pngData()?.write(to: imageURL, options: .atomic)
                    snapshotData = snapshotImage.pngData()
                }
            } else {
                if FileManager.default.fileExists(atPath: filePath.path) {
                    do {
                        let oldData = try Data(contentsOf: filePath)
                        if let oldContainer = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: oldData) {
                            snapshotData = oldContainer.imageData
                        }
                    } catch {
                        print("Failed to read old container for existing world: \(error.localizedDescription)")
                    }
                }
            }
            
            do {
                let container = ARWorldMapContainer(map: map, imageData: snapshotData)
                let containerData = try NSKeyedArchiver.archivedData(withRootObject: container, requiringSecureCoding: true)
                // Use helper extension for file writing if desired.
                try containerData.write(to: filePath, options: .atomic)
               
                self.saveWorldList()
                AppState.shared.isiCloudSyncActive = true
                self.iCloudManager.uploadWorldMap(roomName: roomName, data: containerData, lastModified: timestamp) {
                    print("Synced \(roomName) to CloudKit.")
                    DispatchQueue.main.async {
                        AppState.shared.isiCloudSyncActive = false

                    }

                    if self.shouldDeletePublicAnchors {
                       
                        self.deleteAllAnchorsForPublicRecord(publicRecordName: publicName) { _ in
                            self.shouldDeletePublicAnchors = false
                            }
                        
                    }
                }
            } catch {
                print("Error saving container for \(roomName): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Load World Map
    func loadWorldMap(for roomName: String, sceneView: ARSCNView) {
        print("Attempting to load world map for room: \(roomName)")
        guard let world = savedWorlds.first(where: { $0.name == roomName }) else {
            print("No saved world found with the name: \(roomName)")
            isShowingARGuide = true
            return
        }
       
        let filePath = world.filePath
        print("Loading from file: \(filePath)")
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("File not found at path: \(filePath.path). Trying CloudKit...")
            iCloudManager.loadWorldMap(roomName: roomName) { data, arMap in }
            return
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                let worldMap = container.map
                sceneView.session.pause()
                let configuration = ARWorldTrackingConfiguration()
                configuration.initialWorldMap = worldMap
                configuration.planeDetection = [.horizontal, .vertical]
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    configuration.sceneReconstruction = .mesh
                }
                if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                    coordinator.worldIsLoaded = false
                    coordinator.isLoading = true
                }
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                    coordinator.worldIsLoaded = true
                    print("World loaded. Ready to add new guide anchors.")
                }
                self.isWorldLoaded = true
                self.isShowingARGuide = true
                print("World map for \(roomName) loaded successfully.")
            } else {
                print("Failed to unarchive ARWorldMapContainer using secure method.")
            }
        } catch {
            print("Error loading ARWorldMap for \(roomName): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save World List
    func saveWorldList() {
        if savedWorlds.isEmpty {
                print("Skipping sync because local worlds are empty.")
                return
            }
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try JSONEncoder().encode(savedWorlds)
            try data.write(to: fileURL, options: .atomic)
            indexWorlds()
           

        } catch {
            print("Error saving world list: \(error.localizedDescription)")
        }
    }
    

    func syncLocalWorldsToCloudKit(roomName: String) {
        let privateDB = CKContainer.default().privateCloudDatabase
        var recordsToSave: [CKRecord] = []
        
        for world in savedWorlds {
            if world.name == roomName {
                
                if world.metadataRecordID == nil {
                    let newMetadataID = "metadata-\(UUID().uuidString)"
                    if let index = savedWorlds.firstIndex(where: { $0.name == world.name }) {
                        savedWorlds[index].metadataRecordID = newMetadataID
                        saveWorldList()
                    }
                }
                
                guard let metaIDString = world.metadataRecordID else {
                    print("❌ metadataRecordID is still nil for world: \(world.name)")
                    continue
                }
                let recordID = CKRecord.ID(recordName: metaIDString)
                
                // 3) Create or update the 'WorldMetadata' record
                let record = CKRecord(recordType: metadataRecordType, recordID: recordID)
                record["roomName"] = world.name as CKRecordValue
                record["pin"] = world.pin as CKRecordValue?
                record["cloudRecordID"] = world.cloudRecordID as CKRecordValue?
                record["isCollaborative"] = world.isCollaborative as CKRecordValue
                record["lastModified"] = world.lastModified as CKRecordValue
                
                recordsToSave.append(record)
            }
        }
        
        // If no matching worlds => nothing to do
        guard !recordsToSave.isEmpty else { return }
        
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.modifyRecordsCompletionBlock = { saved, deleted, error in
            if let error = error {
                print("❌ Error syncing worlds to CloudKit: \(error.localizedDescription)")
            } else {
                print("✅ Successfully synced \(saved?.count ?? 0) metadata record(s) to CloudKit.")
            }
        }
        privateDB.add(operation)
    }
    // MARK: - Load Saved Worlds
    func loadSavedWorlds(completion: @escaping () -> Void) {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
            let uniqueWorlds = Array(Dictionary(grouping: decodedWorlds, by: { $0.name }).compactMap { $0.value.first })
            DispatchQueue.main.async {
                self.savedWorlds = uniqueWorlds
                self.indexWorlds()
            }
        } catch {
            DispatchQueue.main.async {
                self.savedWorlds = []
                print("No saved world list found or failed to decode: \(error.localizedDescription)")
            }
        }
        fetchWorldMetadataFromCloudKit {
            
            self.fetchWorldNamesFromCloudKit {
                print("Data synced with CloudKit.")
                let dispatchGroup = DispatchGroup()
                for world in self.savedWorlds {
                    dispatchGroup.enter()
                    self.getAnchorNames(for: world.name) { anchorNames in
                        DispatchQueue.main.async {
                            self.cachedAnchorNames[world.name] = anchorNames
                        }
                        dispatchGroup.leave()
                    }
                    if !FileManager.default.fileExists(atPath: world.filePath.path) {
                        print("Fetching missing data for world: \(world.name)")
                        dispatchGroup.enter()
                        self.iCloudManager.loadWorldMap(roomName: world.name) { data, arMap in
                            if let data = data {
                                self.saveLocallyAfterCloudDownload(roomName: world.name, data: data, lastModified: world.lastModified)
                            }
                            print("Fetched container for \(world.name) and saved locally.")
                            dispatchGroup.leave()
                        }
                    }
                }
                dispatchGroup.notify(queue: .main) {
                    completion()
                }
            }
            
        }
        
        loadSharedLinks()
    }
    
    func fetchWorldMetadataFromCloudKit(completion: @escaping () -> Void) {
        let localWorlds = savedWorlds
            let privateDB = CKContainer.default().privateCloudDatabase
            
            // We'll do them all in parallel with a DispatchGroup.
            let group = DispatchGroup()
            
            for localWorld in localWorlds {
                group.enter()
                
                // 1) Build a query: "roomName == localWorld.name"
                let predicate = NSPredicate(format: "roomName == %@", localWorld.name)
                let query = CKQuery(recordType: metadataRecordType, predicate: predicate)
                
                let operation = CKQueryOperation(query: query)
                var fetchedRecords: [CKRecord] = []
                
                operation.recordFetchedBlock = { record in
                    fetchedRecords.append(record)
                }
                
                operation.queryCompletionBlock = { cursor, error in
                    if let error = error {
                        print("❌ Error fetching metadata for '\(localWorld.name)': \(error.localizedDescription)")
                    } else if let record = fetchedRecords.first {
                        // 2) Convert the record into a WorldModel
                        let roomName = record["roomName"] as? String ?? "Untitled"
                        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
                        
                        var newWorld = WorldModel(name: roomName, lastModified: lastModified)
                        newWorld.pin = record["pin"] as? String
                        newWorld.cloudRecordID = record["cloudRecordID"] as? String
                        newWorld.isCollaborative = record["isCollaborative"] as? Bool ?? false
                        
                        // 3) Merge it with our local data (will pick whichever is newer)
                        self.mergeCloudKitWorlds([newWorld])
                        print("ℹ️ metadata found for '\(localWorld.name)' in CloudKit.")
                    } else {
                        print("ℹ️ No metadata record found for '\(localWorld.name)' in CloudKit.")
                    }
                    group.leave()
                }
                
                privateDB.add(operation)
            }
            
            // 4) Once all queries finish, call completion
            group.notify(queue: .main) {
                completion()
            }
    }
    
     private func mergeCloudKitWorlds(_ cloudWorlds: [WorldModel]) {
        
        for cw in cloudWorlds {
            if let localIndex = savedWorlds.firstIndex(where: { $0.name == cw.name }) {
                // We already have a local world with this name
                let localWorld = savedWorlds[localIndex]
                // Compare lastModified to decide which is newer
              //  if cw.lastModified > localWorld.lastModified {
                    // Cloud is newer: override local metadata
                DispatchQueue.main.async {
                    self.savedWorlds[localIndex].pin = cw.pin
                    self.savedWorlds[localIndex].cloudRecordID = cw.cloudRecordID
                    self.savedWorlds[localIndex].isCollaborative = cw.isCollaborative
                    self.savedWorlds[localIndex].lastModified = cw.lastModified
                }
                   print("collab? \(cw.isCollaborative)")
//                } else {
//                    // Local is newer: do nothing, or push to cloud again if you want
//                }
            } else {
                // No local world with this name, so add it
                DispatchQueue.main.async {
                    
                    self.savedWorlds.append(cw)
                }
            }
        }
        // Save updated local JSON
        self.saveWorldList()
    }
    
    
    @MainActor
    func loadSavedWorldsAsyncForIntents() async throws -> [WorldModel] {
        let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("worldsList.json")
        let data = try Data(contentsOf: fileURL)
        let decodedWorlds = try JSONDecoder().decode([WorldModel].self, from: data)
        let uniqueWorlds = Array(Dictionary(grouping: decodedWorlds, by: { $0.name }).compactMap { $0.value.first })
        self.savedWorlds = uniqueWorlds
        self.indexWorlds()
        return uniqueWorlds
    }
    
    // MARK: - Get Anchor Names
    func getAnchorNames(for worldName: String, completion: @escaping ([String]) -> Void) {
        guard let world = savedWorlds.first(where: { $0.name == worldName }) else {
            print("No saved world found with the name: \(worldName)")
            completion([])
            return
        }
        if !FileManager.default.fileExists(atPath: world.filePath.path) {
            print("File not found for \(worldName). Trying CloudKit...")
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
                if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                    let anchorNames = container.map.anchors.compactMap { $0.name }.filter { $0 != "unknown" }
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
    
    // MARK: - Delete World
    func deleteWorld(roomName: String, publicName: String, completion: (() -> Void)? = nil) {
        // 1. Locate the world model locally.
        guard let index = savedWorlds.firstIndex(where: { $0.name == roomName }) else {
            print("No world found with name \(roomName)")
            completion?()
            return
        }
        let world = savedWorlds[index]
        
        // 2. Delete the local world map file.
        let filePath = world.filePath
        do {
            if FileManager.default.fileExists(atPath: filePath.path) {
                try FileManager.default.removeItem(at: filePath)
                print("Local world file for \(roomName) deleted.")
            }
            // Optionally, delete the associated snapshot if it exists.
            let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_snapshot.png")
            if FileManager.default.fileExists(atPath: snapshotPath.path) {
                try FileManager.default.removeItem(at: snapshotPath)
                print("Local snapshot for \(roomName) deleted.")
            }
        } catch {
            print("Error deleting local files for \(roomName): \(error.localizedDescription)")
        }
        
        // 3. Remove the world from the Spotlight index.
        let uniqueIdentifier = "com.parthant.AR-spotit.\(world.name)"
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [uniqueIdentifier]) { error in
            if let error = error {
                print("Error deleting world from Spotlight index: \(error.localizedDescription)")
            } else {
                print("Successfully removed \(roomName) from Spotlight index.")
            }
        }
        
        // 4. Clear any cached anchor names for this room.
        DispatchQueue.main.async {
            self.cachedAnchorNames[roomName] = nil
        }
        
        // 5. Remove the world from the local saved list and update storage.
        savedWorlds.remove(at: index)
        saveWorldList()
        
        // 6. Delete all CloudKit records for the world, including public records, custom-zone records, and metadata.
        iCloudManager.deleteWorld(roomName: roomName, publicName: publicName) { error in
            if let error = error {
                print("Error deleting world from CloudKit: \(error.localizedDescription)")
            } else {
                print("Deleted world \(roomName) from CloudKit.")
            }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    // MARK: - Save Locally After Cloud Download
    func saveLocallyAfterCloudDownload(roomName: String, data: Data, lastModified: Date) {
        let filePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
        do {
            try data.write(to: filePath, options: .atomic)
            DispatchQueue.main.async {
                if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                    self.savedWorlds[index].lastModified = lastModified
            } else {
                
                    self.savedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                    
                    
                }
            }
            saveWorldList()
            print("World \(roomName) saved locally after CloudKit sync.")
        } catch {
            print("Error saving locally after CloudKit sync: \(error.localizedDescription)")
        }
        do {
            if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data),
               let snapshotData = container.imageData {
                let snapshotURL = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_snapshot.png")
                try snapshotData.write(to: snapshotURL, options: .atomic)
                print("✅ Restored snapshot for \(roomName) from iCloud at: \(snapshotURL.path)")
            }
        } catch {
            print("❌ Could not restore snapshot: \(error)")
        }
    }
    
    // MARK: - Share World via Local File
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
        
        // Copy the file to the Documents directory to prepare it for sharing.
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent("\(currentRoomName).worldmap")
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceFilePath, to: destinationURL)
            print("File ready for sharing at: \(destinationURL)")
            
            // Optional: Load a thumbnail for the preview (for example, the snapshot image saved when the world was saved).
            let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(currentRoomName)_snapshot.png")
            let thumbnailImage = UIImage(contentsOfFile: snapshotPath.path)
            
            // Wrap the file URL in the FilePreviewMetadataProvider.
            let metadataProvider = FilePreviewMetadataProvider(
                fileURL: destinationURL,
                title: "\(currentRoomName) World Map",
                thumbnail: thumbnailImage
            )
            
            let activityController = UIActivityViewController(activityItems: [metadataProvider], applicationActivities: nil)
            
            // Configure the popover presentation for iPad.
            if let popoverController = activityController.popoverPresentationController,
               let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController,
               let baseView = rootViewController.view {
                popoverController.sourceView = baseView
                popoverController.sourceRect = CGRect(
                    x: baseView.bounds.midX,
                    y: baseView.bounds.midY,
                    width: 0,
                    height: 0
                )
                popoverController.permittedArrowDirections = []
            }
            
            // Present the share sheet.
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
    
    // MARK: - Check And Sync If Newer
    func checkAndSyncIfNewer(for roomName: String, completion: @escaping () -> Void) {
        guard let localWorld = savedWorlds.first(where: { $0.name == roomName }) else {
            completion()
            return
        }
        iCloudManager.fetchLastModified(for: roomName) { cloudLastModified in
            guard let cloudLastModified = cloudLastModified,
                  cloudLastModified > localWorld.lastModified else {
                completion()
                return
            }
            print("⏫ Found newer data in iCloud for \(roomName). Downloading...")
            self.iCloudManager.loadWorldMap(roomName: roomName) { data, arMap in
                if let data = data {
                    self.saveLocallyAfterCloudDownload(roomName: roomName, data: data, lastModified: cloudLastModified)
                }
                completion()
            }
        }
    }
    
    // MARK: - Load Saved Worlds Async
    func loadSavedWorldsAsync() async {
        await withCheckedContinuation { continuation in
            self.loadSavedWorlds {
                continuation.resume()
            }
        }
    }
    
    /// Fetches the world record for a given room name.
    func fetchWorldRecord(for roomName: String, completion: @escaping (CKRecord?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(
            recordType: recordType,
            predicate: predicate,
            zoneID: iCloudManager.customZoneID,
            desiredKeys: ["roomName"]
        ) { result in
            switch result {
            case .success(let records):
                completion(records.first)
            case .failure(let error):
                print("Error fetching world record: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    //MARK: Share iCloud Link
    func shareWorldViaCloudKit(roomName: String, pin: String) {
        // Create the iCloud collaboration link.
        iCloudManager.createCollabLink(for: roomName, with: pin) { shareURL in
            guard let shareURL = shareURL else {
                print("Failed to create collaboration share link for room: \(roomName)")
                AppState.shared.isCreatingLink = false
                return
            }
            
            // Fetch the world record to update local collaborative state.
            self.fetchWorldRecord(for: roomName) { record in
                if let record = record {
                    self.startCollaborativeSession(with: record, roomName: roomName)
                    if let index = self.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                        DispatchQueue.main.async {
                            self.savedWorlds[index].cloudRecordID = record.recordID.recordName
                            self.savedWorlds[index].isCollaborative = true
                            if self.savedWorlds[index].pin == nil {
                                self.savedWorlds[index].pin = pin
                            }
                            self.saveWorldList()
                            self.syncLocalWorldsToCloudKit(roomName: roomName)
                        }
                        print("Collaborative info updated for room: \(roomName)")
                    } else {
                        print("Saved world for \(roomName) not found.")
                    }
                } else {
                    print("World record for \(roomName) not found.")
                }
            }
            
            AppState.shared.isCreatingLink = false
            
            // Optional: Load a thumbnail image for the preview from your saved snapshot.
            let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_snapshot.png")
            let thumbnailImage = UIImage(contentsOfFile: snapshotPath.path)
            
            // Wrap the URL with rich metadata.
            let metadataProvider = LinkMetadataProvider(url: shareURL, title: roomName, image: thumbnailImage)
            
            // Present the share sheet.
            DispatchQueue.main.async {
                let activityController = UIActivityViewController(activityItems: [metadataProvider], applicationActivities: nil)
                
                // Configure popover for iPad.
                if let popoverController = activityController.popoverPresentationController,
                   let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController,
                   let baseView = rootViewController.view {
                    popoverController.sourceView = baseView
                    popoverController.sourceRect = CGRect(
                        x: baseView.bounds.midX,
                        y: baseView.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    popoverController.permittedArrowDirections = []
                }
                
                // Present the activity controller.
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
   //MARK: Fetch names from cloudKit
    func fetchWorldNamesFromCloudKit(completion: @escaping () -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        privateDB.fetch(withQuery: query,
                        inZoneWith: nil,
                        desiredKeys: ["roomName", "lastModified"],
                        resultsLimit: CKQueryOperation.maximumResults) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
            switch result {
            case .success(let (matchResults, _)):
                var fetchedWorlds: [WorldModel] = []
                for (recordID, recordResult) in matchResults {
                    switch recordResult {
                    case .success(let record):
                        let roomName = record["roomName"] as? String ?? "Unnamed"
                        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
                        print("Fetched record \(recordID.recordName) with roomName: \(roomName)")
                        
                        // Compare with local data if necessary; for now, simply append if not already present.
                        if !self.savedWorlds.contains(where: { $0.name == roomName }) {
                            fetchedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                        }
                    case .failure(let error):
                        print("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
                    }
                }
                DispatchQueue.main.async {
                    self.savedWorlds.append(contentsOf: fetchedWorlds)
                    self.saveWorldList()
                    completion()
                }
            case .failure(let error):
                print("Error fetching world names from CloudKit: \(error.localizedDescription)")
                completion()
            }
        }
    }
    
    // MARK: - Restore Collaborative World from Persistent Storage
    func restoreCollaborativeWorld() {
        print("Restoring collaborative world. Saved worlds: \(self.savedWorlds)")
        guard let collabWorld = self.savedWorlds.first(where: { $0.isCollaborative && $0.cloudRecordID != nil }) else {
            print("No collaborative world found in saved worlds.")
            return
        }
        let recordID = CKRecord.ID(recordName: collabWorld.cloudRecordID!, zoneID: self.iCloudManager.customZoneID)
        CKContainer.default().privateCloudDatabase.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let record = record {
                    self.currentWorldRecord = record
                    print("Collaborative world restored from CloudKit.")
                } else {
                    print("Error restoring collaborative world: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
    }
    
    func restoreCollaborativeWorldAndRestartSession(sceneView: ARSCNView) {
        print("Restoring collaborative world. Saved worlds: \(self.savedWorlds)")
        guard let collabWorld = self.savedWorlds.first(where: { $0.isCollaborative && $0.cloudRecordID != nil }) else {
            print("No collaborative world found in saved worlds.")
            return
        }
        let recordID = CKRecord.ID(recordName: collabWorld.cloudRecordID!, zoneID: self.iCloudManager.customZoneID)
        CKContainer.default().privateCloudDatabase.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let record = record {
                    self.currentWorldRecord = record
                    print("Collaborative world restored from CloudKit.")
                    // Load the shared ARWorldMap from the saved file.
                    let filePath = collabWorld.filePath
                    if let data = try? Data(contentsOf: filePath),
                       let container = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                        let sharedMap = container.map
                        // Restart the AR session with the shared world map.
                        let configuration = ARWorldTrackingConfiguration()
                        configuration.initialWorldMap = sharedMap
                        configuration.planeDetection = [.horizontal, .vertical]
                        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                            configuration.sceneReconstruction = .mesh
                        }
                        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                        print("AR session restarted with shared world map.")
                    } else {
                        print("Failed to load shared world map from local file.")
                    }
                } else {
                    print("Error restoring collaborative world: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
    }
    
    func removeCollab(roomName: String) {
        iCloudManager.removeCollaboration(for: roomName) { _ in
            let drop = Drop.init(title: "Removed \(roomName) collaboration")
            Drops.show(drop)
        }
    }
    
    func deleteAllAnchorsForPublicRecord(publicRecordName: String, completion: @escaping (Error?) -> Void) {
        let publicDB = CKContainer.default().publicCloudDatabase
        let parentRecordID = CKRecord.ID(recordName: publicRecordName)
        
        // The fieldName ("worldReference") should match the reference field in your "Anchor" records
        let parentReference = CKRecord.Reference(recordID: parentRecordID, action: .none)
        let predicate = NSPredicate(format: "worldReference == %@", parentReference)
        let query = CKQuery(recordType: "Anchor", predicate: predicate)
        
        var anchorsToDelete: [CKRecord.ID] = []
        let queryOp = CKQueryOperation(query: query)
        
        queryOp.recordFetchedBlock = { record in
            anchorsToDelete.append(record.recordID)
        }
        
        queryOp.queryCompletionBlock = { cursor, error in
            if let error = error {
                // If the query fails, pass the error back and stop.
                print("❌ Error querying anchors: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            // If we have more results (cursor != nil), you'd typically
            // continue the query with another CKQueryOperation here.
            // For simplicity, this sample handles only a single batch.
            
            guard !anchorsToDelete.isEmpty else {
                print("ℹ️ No anchors found for public record '\(publicRecordName)'. Nothing to delete.")
                completion(nil)
                return
            }
            
            // Now delete all the anchor records that reference this world
            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: anchorsToDelete)
            deleteOp.modifyRecordsCompletionBlock = { _, deletedIDs, deleteError in
                if let deleteError = deleteError {
                    print("❌ Error deleting anchors: \(deleteError.localizedDescription)")
                    completion(deleteError)
                } else {
                    print("✅ Successfully deleted \(deletedIDs?.count ?? 0) anchor(s) for public record '\(publicRecordName)'.")
                    completion(nil)
                }
            }
            
            publicDB.add(deleteOp)
        }
        
        publicDB.add(queryOp)
    }


}


