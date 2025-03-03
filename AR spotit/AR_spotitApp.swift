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
import TipKit

@main
struct AR_spotitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var worldManager = WorldManager.shared
    @State private var isActive = false
    let sceneDelegate = MySceneDelegate()
    @StateObject var appState = AppState.shared
    @AppStorage("isShowedWelcome") private var isShowedWelcomeGuide: Bool = false

    var body: some Scene {
        WindowGroup {
            
            
            if !isShowedWelcomeGuide {
                GeometryReader { geometry in
                    WelcomeView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .zIndex(2)
                }
            } else {
            ZStack {
                WorldsView()
                    .accentColor(.primary)
                    .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)
                    .onOpenURL { url in
                        print("SwiftUI onOpenURL received: \(url.absoluteString)")
                        
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
                        else if url.isFileURL {
                            print("Handling as local file URL.")
                            handleIncomingWorldFile(url)
                        }
                        
                        else {
                            print("Unknown URL; handling as fallback.")
                            handleIncomingWorldFile(url)
                        }
                    }
                    .sheet(isPresented: $worldManager.isImportingWorld) {
                        ImportWorldSheet()
                            .environmentObject(worldManager)
                            .conditionalModifier(!UIDevice.isIpad) { view in
                                view.presentationDetents([.fraction(0.4)])
                            }
                    }
                
                if !isActive && isShowedWelcomeGuide {
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
                    
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.4)])
                    }
                    
                    
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
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.4)])
                    }
                    
                    
                } else {
                    Text("Missing pending record data.")
                }
            }
            .sheet(isPresented: $appState.isShowingCollaborationChoiceSheet) {
                if let roomName = appState.pendingRoomName {
                    
                    CollaborationOptionSheet(
                        roomName: roomName,
                        onCollaborate: {
                            // User chose to collaborate: they must enter a PIN.
                            appState.isViewOnly = false
                            appState.isShowingCollaborationChoiceSheet = false
                            appState.isShowingPinSheet = true
                        },
                        onViewOnly: {
                            // User chose view-only: set flag and show open/save sheet.
                            appState.isViewOnly = true
                            appState.isShowingCollaborationChoiceSheet = false
                            appState.isShowingOpenSaveSheet = true
                        },
                        onCancel: {
                            appState.isShowingCollaborationChoiceSheet = false
                        }
                    )
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.4)])
                    }
                } else {
                    Text("Missing room data.")
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
                        try? Tips.configure()
                        
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notifications.incomingShareURL)) { notification in
                if let object = notification.object {
                    if let metadata = object as? CKShare.Metadata {
                        print("Notification: Received CKShareMetadata directly.")
                        handleIncomingShareMetadata(metadata)
                    }
                }
            }
            
            
        }
        }
    }
    
    
   
    
}

// MARK: - URL, CloudKit Share, & Spotlight Handling
private extension AR_spotitApp {
    
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
    
    private func handleIncomingShareMetadata(_ metadata: CKShare.Metadata) {
        DispatchQueue.main.async {
            AppState.shared.isOpeningSharedLink = true
        }
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
                WorldManager.shared.processIncomingSharedRecord(sharedRecord, withShare: share)
            } else {
                let rootRecordID = metadata.rootRecordID
                print("No rootRecord in share; fetching using rootRecordID: \(rootRecordID)")
                CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                    if let fetchError = fetchError {
                        print("Error fetching root record: \(fetchError.localizedDescription)")
                    } else if let fetchedRecord = fetchedRecord {
                        print("Fetched root record via fetch: \(fetchedRecord.recordID)")
                        WorldManager.shared.processIncomingSharedRecord(fetchedRecord, withShare: share)
                       
                    }
                }
            }
        }
        acceptOperation.acceptSharesResultBlock = { result in
            print("Share acceptance operation completed with result: \(result)")
        }
        CKContainer.default().add(acceptOperation)
    }
    
    private func handleIncomingWorldFile(_ url: URL) {
        guard url.pathExtension == "arworld" || url.pathExtension == "worldmap" else {
            print("Unknown file type: \(url.pathExtension)")
            return
        }
        worldManager.importWorldFromURL(url)
    }
    
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
    
    private func verifyPin(_ enteredPin: String, against storedPinHash: String) -> Bool {
        let enteredHash = sha256(enteredPin) // implement your sha256() function
        return enteredHash == storedPinHash
    }
    
}

extension UIDevice {
    static var isIpad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
