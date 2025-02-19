//
//  AR_spotitApp.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//

import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight
import CloudKit
import Drops

class AppState: ObservableObject {
    static let shared = AppState() // Singleton instance
    @Published var isWorldUpdated: Bool = false {
        didSet {
            print("isWorldUpdated changed to: \(isWorldUpdated)")
        }
    }
    @Published var isiCloudShare: Bool = false {
        didSet {
            print("isCloudShare changed to: \(isiCloudShare)")
        }
    }
    
    @Published var publicRecordName: String = "" {
        didSet {
            print("publicRecordName changed to: \(publicRecordName)")
        }
    }
    @Published var isCreatingLink: Bool = false {
        didSet {
            print("isCreatingLink changed to: \(isCreatingLink)")
        }
    }
    
    @Published var isShowingPinSheet = false
        @Published var isShowingOpenSaveSheet = false
    @Published var pendingSharedRecord: CKRecord?
        @Published var pendingAssetFileURL: URL?
        @Published var pendingRoomName: String?
    
}

@main
struct AR_spotitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var worldManager = WorldManager.shared
    @State private var isActive = false
    let sceneDelegate = MySceneDelegate()
    @StateObject var appState = AppState.shared  // Use our shared app state

    var body: some Scene {
        WindowGroup {
            ZStack {
                WorldsView()
                    .accentColor(.primary)
                    .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)
                    .onOpenURL { url in
                        print("SwiftUI onOpenURL received: \(url.absoluteString)")
                        
                        // Check if the URL has a recordID query parameter (i.e. it's a collab link)
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let recordIDQueryItem = components.queryItems?.first(where: { $0.name == "recordID" }),
                           let recordIDString = recordIDQueryItem.value {
                            
                            print("Collaboration URL detected with recordID: \(recordIDString)")
                            let recordID = CKRecord.ID(recordName: recordIDString)
                            
                            // Fetch the world record from the public database.
                            CKContainer.default().publicCloudDatabase.fetch(withRecordID: recordID) { record, error in
                                if let error = error {
                                    print("Error fetching world record from public DB: \(error.localizedDescription)")
                                    return
                                }
                                guard let publicRecord = record else {
                                    print("No world record found for recordID: \(recordIDString)")
                                    return
                                }
                                DispatchQueue.main.async {
                                    let roomName = publicRecord["roomName"] as? String ?? "Untitled"
                                    WorldManager.shared.startCollaborativeSession(with: publicRecord, roomName: roomName)
                                    print("Collaboration session started for room: \(roomName)")
                                    // Post a notification or navigate to your AR screen as needed:
                                    NotificationCenter.default.post(name: Notifications.incomingShareMapReady, object: nil)
                                }
                            }
                        }
                        // If it's a local file URL, handle it as before.
                        else if url.isFileURL {
                            print("Handling as local file URL.")
                            handleIncomingWorldFile(url)
                        }
                        // If it's an iCloud share URL, handle that.
                        else if url.host == "www.icloud.com" && url.path.contains("share") {
                            print("Handling as CloudKit share URL.")
                            handleIncomingShareURL(url)
                        }
                        // Otherwise, fallback.
                        else {
                            print("Unknown URL; handling as fallback.")
                            handleIncomingWorldFile(url)
                        }
                    }
                    .sheet(isPresented: $worldManager.isImportingWorld) {
                        ImportWorldSheet()
                            .environmentObject(worldManager)
                            .presentationDetents([.fraction(0.4)])
                    }
                
                if !isActive {
                    PhysicsDotsAnimationView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .sheet(isPresented: $appState.isShowingPinSheet) {
                if let roomName = appState.pendingRoomName,
                   let sharedRecord = appState.pendingSharedRecord {
                    // Get the stored PIN hash from the record.
                    let storedPinHash = sharedRecord["pinHash"] as? String ?? ""
                    PinEntrySheet(
                        roomName: roomName,
                        storedPinHash: storedPinHash,
                        onConfirm: { enteredPin in
                            // Verify the entered PIN.
                            if verifyPin(enteredPin, against: storedPinHash) {
                                print("✅ PIN correct; proceeding to open/save sheet.")
                                appState.isShowingPinSheet = false
                                appState.isShowingOpenSaveSheet = true
                            } else {
                                
                                print("❌ Incorrect PIN.")
                                Drops.show("⚠️ Incorrect Key, please try again.")
                               // appState.isShowingPinSheet = false
                            }
                        },
                        onCancel: {
                            appState.isShowingPinSheet = false
                        }
                    )
                    .presentationDetents([.fraction(0.4)])

                } else {
                    Text("Missing pending record data.")
                }
            }
            .sheet(isPresented: $appState.isShowingOpenSaveSheet) {
                if let roomName = appState.pendingRoomName,
                   let assetURL = appState.pendingAssetFileURL,
                   let sharedRecord = appState.pendingSharedRecord {
                    OpenOrSaveSheet(
                        roomName: roomName,
                        assetFileURL: assetURL,
                        sharedRecord: sharedRecord,
                        onOpen: {
                            openSharedWorld(sharedRecord: sharedRecord, assetURL: assetURL)
                            appState.isShowingOpenSaveSheet = false
                        },
                        onSave: {
                            saveSharedWorld(sharedRecord: sharedRecord, assetURL: assetURL, roomName: roomName)
                            appState.isShowingOpenSaveSheet = false
                        },
                        onCancel: {
                            appState.isShowingOpenSaveSheet = false
                        }
                    )
                    .presentationDetents([.fraction(0.4)])

                } else {
                    Text("Missing pending record data.")
                }
            }
            .withHostingWindow { window in
                if let windowScene = window?.windowScene {
                    self.sceneDelegate.originalDelegate = windowScene.delegate
                    windowScene.delegate = self.sceneDelegate
                }
            }
            .onAppear {
                iCloudManager.shared.worldManager = WorldManager.shared
                Task {
                    try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notifications.incomingShareURL)) { notification in
                if let object = notification.object {
                    if let metadata = object as? CKShare.Metadata {
                        print("Notification: Received CKShareMetadata directly.")
                        handleIncomingShareMetadata(metadata)
                    } else if let url = object as? URL {
                        print("Notification: Received URL: \(url.absoluteString)")
                        handleIncomingShareURL(url)
                    }
                }
            }
        }
    }
    
    private func openSharedWorld(sharedRecord: CKRecord, assetURL: URL) {
            do {
                let data = try Data(contentsOf: assetURL)
                print("✅ Loaded asset data of size: \(data.count) bytes")
                if let container = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: ARWorldMapContainer.self,
                    from: data
                ) {
                    let arWorldMap = container.map
                    WorldManager.shared.sharedARWorldMap = arWorldMap
                    WorldManager.shared.sharedWorldName = sharedRecord["roomName"] as? String ?? "Untitled"
                    print("✅ Will open shared ARWorldMap in memory.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: Notifications.incomingShareMapReady,
                            object: nil
                        )
                    }
                } else {
                    print("❌ Could not decode ARWorldMap from container.")
                }
            } catch {
                print("❌ Error decoding ARWorldMap: \(error.localizedDescription)")
            }
        }
        
        private func saveSharedWorld(sharedRecord: CKRecord, assetURL: URL, roomName: String) {
            do {
                let data = try Data(contentsOf: assetURL)
                print("✅ Loaded asset data of size: \(data.count) bytes")
                let localFilePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
                try data.write(to: localFilePath, options: .atomic)
                print("✅ Shared asset data written to local file: \(localFilePath.path)")
                WorldManager.shared.importWorldFromURL(localFilePath)
            } catch {
                print("❌ Error saving shared asset data: \(error.localizedDescription)")
            }
        }
 
    
}


// MARK: - URL, CloudKit Share, & Spotlight Handling
private extension AR_spotitApp {
    // MARK: -iCLoud Share Link
    
    private func processSharedRecord(_ sharedRecord: CKRecord, withShare share: CKShare) {
            let roomName = sharedRecord["roomName"] as? String ?? "Untitled"
            let publicRecordName = sharedRecord["publicRecordName"] as? String ?? ""
            
            DispatchQueue.main.async {
                WorldManager.shared.sharedZoneID = share.recordID.zoneID
                print("Shared zone ID set to: \(WorldManager.shared.sharedZoneID!)")
                AppState.shared.publicRecordName = publicRecordName
                AppState.shared.isiCloudShare = true
            }
            
            // Start the collaborative session.
            WorldManager.shared.startCollaborativeSession(with: sharedRecord, roomName: roomName)
            
            guard
                let asset = sharedRecord["mapAsset"] as? CKAsset,
                let assetFileURL = asset.fileURL
            else {
                print("❌ Failed to get CKAsset or assetFileURL")
                return
            }
        DispatchQueue.main.async {
            AppState.shared.pendingSharedRecord = sharedRecord
            AppState.shared.pendingAssetFileURL = assetFileURL
            AppState.shared.pendingRoomName = roomName
        }
            // Store record details in AppState so sheets can use them.
          
            
            // If a PIN is required, show the PIN sheet; otherwise, show the open/save sheet.
            let pinRequired = sharedRecord["pinRequired"] as? Bool ?? false
            if pinRequired {
                print("🔒 PIN is required. Showing PIN sheet...")
                DispatchQueue.main.async {
                    AppState.shared.isShowingPinSheet = true
                }
            } else {
                print("🔓 No PIN required. Showing open/save sheet...")
                DispatchQueue.main.async {
                    AppState.shared.isShowingOpenSaveSheet = true
                }
            }
        }
    
    private func showOpenOrSaveAlert(sharedRecord: CKRecord,
                                     assetFileURL: URL,
                                     roomName: String) {
        do {
            let data = try Data(contentsOf: assetFileURL)
            print("✅ Loaded asset data of size: \(data.count) bytes")
            
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "\(sharedRecord["roomName"] ?? "AR Area") Received",
                    message: "Would you like to open now or save locally?",
                    preferredStyle: .alert
                )
                
                // "Open Now"
                let openAction = UIAlertAction(title: "Open Now", style: .default) { _ in
                    do {
                        if let container = try NSKeyedUnarchiver.unarchivedObject(
                            ofClass: ARWorldMapContainer.self,
                            from: data
                        ) {
                            let arWorldMap = container.map
                            WorldManager.shared.sharedARWorldMap = arWorldMap
                            WorldManager.shared.sharedWorldName = sharedRecord["roomName"] as? String ?? "Untitled"
                            print("✅ Will open shared ARWorldMap in memory.")
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(
                                    name: Notifications.incomingShareMapReady,
                                    object: nil
                                )
                            }
                        } else {
                            print("❌ Could not decode ARWorldMap from container.")
                        }
                    } catch {
                        print("❌ Error decoding ARWorldMap: \(error.localizedDescription)")
                    }
                }
                
                // "Save Locally"
                let saveAction = UIAlertAction(title: "Save Locally", style: .default) { _ in
                    do {
                        let localFilePath = WorldModel.appSupportDirectory
                            .appendingPathComponent("\(roomName)_worldMap")
                        try data.write(to: localFilePath, options: .atomic)
                        print("✅ Shared asset data written to local file: \(localFilePath.path)")
                        
                        WorldManager.shared.importWorldFromURL(localFilePath)
                    } catch {
                        print("❌ Error saving shared asset data: \(error.localizedDescription)")
                    }
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                
                alert.addAction(openAction)
                alert.addAction(saveAction)
                alert.addAction(cancelAction)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(alert, animated: true)
                } else {
                    print("❌ Could not find a rootViewController to present alert.")
                }
            }
        } catch {
            print("❌ Error reading asset data: \(error.localizedDescription)")
        }
    }
    
    private func showPinErrorAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Incorrect PIN", message: "You entered the wrong code.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }

//    private func processSharedRecord(_ sharedRecord: CKRecord, withShare share: CKShare) {
//    
//        let roomName = sharedRecord["roomName"] as? String ?? "Untitled"
//        let publicRecordName = sharedRecord["publicRecordName"] as? String ?? ""
//        
//        DispatchQueue.main.async {
//            WorldManager.shared.sharedZoneID = share.recordID.zoneID
//            print("Shared zone ID set to: \(WorldManager.shared.sharedZoneID!)")
//
//            AppState.shared.publicRecordName = publicRecordName
//            AppState.shared.isiCloudShare = true
//        }
//     
//        
//          // Start a collaborative session in WorldManager
//        WorldManager.shared.startCollaborativeSession(with: sharedRecord, roomName: roomName)
//        
//        guard
//            let asset = sharedRecord["mapAsset"] as? CKAsset,
//            let assetFileURL = asset.fileURL
//        else {
//            print("❌ Failed to get CKAsset or assetFileURL")
//            return
//        }
//        
//        do {
//            let data = try Data(contentsOf: assetFileURL)
//            print("✅ Loaded asset data of size: \(data.count) bytes")
//            
//            DispatchQueue.main.async() {
//                // 1) Create a UIKit alert
//                let alert = UIAlertController(
//                    title: "\(sharedRecord["roomName"] ?? "AR Area") Received",
//                    message: "Would you like to open now or save locally?",
//                    preferredStyle: .alert
//                )
//                
//                // 2) "Open Now" → Decode ARWorldMap in memory
//                let openAction = UIAlertAction(title: "Open Now", style: .default) { _ in
//                    do {
//                        if let container = try NSKeyedUnarchiver.unarchivedObject(
//                            ofClass: ARWorldMapContainer.self,
//                            from: data
//                        ) {
//                            let arWorldMap = container.map
//                            WorldManager.shared.sharedARWorldMap = arWorldMap
//                            WorldManager.shared.sharedWorldName = sharedRecord["roomName"] as? String ?? "Untitled"
//                            print("✅ Will open shared ARWorldMap in memory.")
//                            
//                            // Optionally post a notification or navigate to your AR screen:
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                NotificationCenter.default.post(
//                                    name: Notifications.incomingShareMapReady,
//                                    object: nil
//                                )
//                            }
//                        } else {
//                            print("❌ Could not decode ARWorldMap from container.")
//                        }
//                    } catch {
//                        print("❌ Error decoding ARWorldMap: \(error.localizedDescription)")
//                    }
//                }
//                
//                // 3) "Save Locally" → old logic (write to local file)
//                let saveAction = UIAlertAction(title: "Save Locally", style: .default) { _ in
//                    do {
//                        let roomName = (sharedRecord["roomName"] as? String) ?? "UnknownWorld"
//                        let localFilePath = WorldModel.appSupportDirectory
//                            .appendingPathComponent("\(roomName)_worldMap")
//                        
//                        try data.write(to: localFilePath, options: .atomic)
//                        print("✅ Shared asset data written to local file: \(localFilePath.path)")
//                        
//                        // Then import so it shows in your saved worlds
//                        WorldManager.shared.importWorldFromURL(localFilePath)
//                    } catch {
//                        print("❌ Error saving shared asset data: \(error.localizedDescription)")
//                    }
//                }
//                
//                // 4) "Cancel"
//                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
//                
//                // 5) Add actions
//                alert.addAction(openAction)
//                alert.addAction(saveAction)
//                alert.addAction(cancelAction)
//                
//                // 6) Present the alert on the root VC
//                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//                   let rootVC = windowScene.windows.first?.rootViewController {
//                    rootVC.present(alert, animated: true)
//                } else {
//                    print("❌ Could not find a rootViewController to present alert.")
//                }
//            }
//        } catch {
//            print("❌ Error processing ARWorldMap data: \(error.localizedDescription)")
//        }
//    }
    
    private func handleIncomingShareMetadata(_ metadata: CKShare.Metadata) {
        print("Handling incoming share metadata directly: \(metadata)")
        let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        acceptOperation.perShareCompletionBlock = { meta, share, error in
            print("perShareCompletionBlock triggered")
            if let error = error {
                print("Error in perShareCompletionBlock: \(error.localizedDescription)")
                return
            }
            guard let share = share else {
                print("No share returned in perShareCompletionBlock")
                return
            }
            if let sharedRecord = share.value(forKey: "rootRecord") as? CKRecord {
                print("Fetched sharedRecord from share: \(sharedRecord.recordID)")
                self.processSharedRecord(sharedRecord, withShare: share)
            } else {
                let rootRecordID = metadata.rootRecordID
                print("No rootRecord in share; fetching using rootRecordID: \(rootRecordID)")
                CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                    if let fetchError = fetchError {
                        print("Error fetching root record: \(fetchError.localizedDescription)")
                    } else if let fetchedRecord = fetchedRecord {
                        print("Fetched root record via fetch: \(fetchedRecord.recordID)")
                        self.processSharedRecord(fetchedRecord, withShare: share)
                    }
                }
            }
        }
        acceptOperation.acceptSharesResultBlock = { result in
            print("Share acceptance operation completed with result: \(result)")
        }
        CKContainer.default().add(acceptOperation)
    }
    
    private func handleIncomingShareURL(_ url: URL) {
        print("Incoming CloudKit share URL: \(url.absoluteString)")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        let cleanedURL = components?.url ?? url
        print("Cleaned share URL: \(cleanedURL.absoluteString)")
        CKContainer.default().fetchShareMetadata(with: cleanedURL) { shareMetadata, error in
            if let error = error {
                print("Error fetching share metadata: \(error.localizedDescription)")
                return
            }
            guard let metadata = shareMetadata else {
                print("No share metadata found.")
                return
            }
            let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            acceptOperation.perShareCompletionBlock = { meta, share, error in
                print("perShareCompletionBlock triggered")
                if let error = error {
                    print("Error in perShareCompletionBlock: \(error.localizedDescription)")
                    return
                }
                guard let share = share else {
                    print("No share returned in perShareCompletionBlock")
                    return
                }
                if let sharedRecord = share.value(forKey: "rootRecord") as? CKRecord {
                    print("Fetched sharedRecord from share: \(sharedRecord.recordID)")
                    self.processSharedRecord(sharedRecord, withShare: share)
                } else {
                    let rootRecordID = metadata.rootRecordID
                    print("No rootRecord in share; fetching using rootRecordID: \(rootRecordID)")
                    CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                        if let fetchError = fetchError {
                            print("Error fetching root record: \(fetchError.localizedDescription)")
                        } else if let fetchedRecord = fetchedRecord {
                            print("Fetched root record via fetch: \(fetchedRecord.recordID)")
                            self.processSharedRecord(fetchedRecord, withShare: share)
                        }
                    }
                }
            }
            acceptOperation.acceptSharesResultBlock = { result in
                print("Share acceptance operation completed with result: \(result)")
            }
            CKContainer.default().add(acceptOperation)
        }
    }
    
    //MARK: Handle local .worldmap
    private func handleIncomingWorldFile(_ url: URL) {
        guard url.pathExtension == "arworld" || url.pathExtension == "worldmap" else {
            print("Unknown file type: \(url.pathExtension)")
            return
        }
        worldManager.importWorldFromURL(url)
    }
    
    //MARK: Handle spotlight activity
    func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        print("Handling Spotlight user activity")
        guard let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            print("No unique identifier found in user activity")
            return
        }
        
        let worldPrefix = "com.parthant.AR-spotit."
        let itemPrefix = "item.com.parthant.AR-spotit."
        
        if uniqueIdentifier.hasPrefix(worldPrefix) {
            let worldName = String(uniqueIdentifier.dropFirst(worldPrefix.count))
            Task {
                if worldManager.savedWorlds.isEmpty {
                    print("savedWorlds is empty. Waiting for worlds to load...")
                    await worldManager.loadSavedWorldsAsync()
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notifications.openWorldNotification,
                        object: nil,
                        userInfo: ["worldName": worldName]
                    )
                    print("Selected world set to \(worldName) via Spotlight")
                }
            }
        } else if uniqueIdentifier.hasPrefix(itemPrefix) {
            let remaining = uniqueIdentifier.dropFirst(itemPrefix.count)
            let components = remaining.split(separator: ".", maxSplits: 1)
            guard components.count == 2 else {
                print("Could not parse searchable item identifier: \(uniqueIdentifier)")
                return
            }
            let worldName = String(components[0])
            let itemName = String(components[1])
            Task {
                if worldManager.savedWorlds.isEmpty {
                    print("savedWorlds is empty. Waiting for worlds to load...")
                    await worldManager.loadSavedWorldsAsync()
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notifications.findItemNotification,
                        object: nil,
                        userInfo: ["itemName": itemName, "worldName": worldName]
                    )
                    print("Selected item \(itemName) in world \(worldName) via Spotlight")
                }
            }
        } else {
            print("Unique identifier does not match known prefixes")
        }
    }
    
    
    private func promptForPin(completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Enter PIN", message: nil, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "4-digit code"
                textField.keyboardType = .numberPad
            }
            let confirm = UIAlertAction(title: "OK", style: .default) { _ in
                let pin = alert.textFields?.first?.text ?? ""
                completion(pin)
            }
            alert.addAction(confirm)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }

    private func verifyPin(_ enteredPin: String, against storedPinHash: String) -> Bool {
        let enteredHash = sha256(enteredPin) // implement your sha256() function
        return enteredHash == storedPinHash
    }
}
