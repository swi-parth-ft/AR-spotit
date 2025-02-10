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
import CryptoKit

func sha256Hash(of data: Data) -> String {
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        CKContainer.default().accountStatus { status, error in
            if let error = error {
                print("Error checking CloudKit account status: \(error.localizedDescription)")
            } else {
                print("CloudKit account status: \(status)")
                let container = CKContainer.default()
                
                print("🔍 Container Identifier: \(container.containerIdentifier ?? "Unknown")")
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("AppDelegate open URL: \(url.absoluteString)")
        // Forward URL handling if needed, for example:
        NotificationCenter.default.post(name: Notification.Name("IncomingURL"), object: url)
        return true
    }
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            print("AppDelegate continue userActivity: \(url.absoluteString)")
            NotificationCenter.default.post(name: Notification.Name("IncomingURL"), object: url)
        }
        return true
    }
}
class AppState: ObservableObject {
    static let shared = AppState() // Singleton instance
    @Published var isWorldUpdated: Bool = false {
        
        didSet {
            print("isWorldUpdated changed to: \(isWorldUpdated)")
        }
    }
    
}


@main
struct AR_spotitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Ideally pass WorldManager down via environment or as a singleton
    @StateObject var worldManager = WorldManager()
    @State private var isActive = false // Tracks if the splash screen is active
    let sceneDelegate = MySceneDelegate()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main Content View
                WorldsView()
                    .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)
                
                    .onOpenURL { url in
                        print("SwiftUI onOpenURL received: \(url.absoluteString)")
                        if url.isFileURL {
                            print("Handling as local file URL.")
                            handleIncomingWorldFile(url)
                        } else if url.host == "www.icloud.com" && url.path.contains("share") {
                            print("Handling as CloudKit share URL.")
                            handleIncomingShareURL(url)
                        } else {
                            print("Unknown URL; handling as fallback.")
                            handleIncomingWorldFile(url)
                        }
                    }
                    .sheet(isPresented: $worldManager.isImportingWorld) {
                        ImportWorldSheet()
                            .environmentObject(worldManager)
                            .presentationDetents([.fraction(0.4)])
                    }
                    
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                                            if let url = userActivity.webpageURL {
                                                print("Received universal link: \(url.absoluteString)")
                                                if url.absoluteString.contains("ckshare") {
                                                    print("Handling as a CloudKit share URL via user activity.")
                                                    handleIncomingShareURL(url)
                                                } else {
                                                    print("Handling as a world file URL via user activity.")
                                                    handleIncomingWorldFile(url)
                                                }
                                            }
                                        }
                
                // Splash Screen
                if !isActive {
                    PhysicsDotsAnimationView()
                        .transition(.opacity) // Fade in/out transition
                        .zIndex(1) // Ensure it's on top
                }
            }
            
            .withHostingWindow { window in
                            if let windowScene = window?.windowScene {
                                // Save the original delegate.
                                self.sceneDelegate.originalDelegate = windowScene.delegate
                                // Set our custom delegate.
                                windowScene.delegate = self.sceneDelegate
                            }
                        }
            .onAppear {
                // Delay the splash screen for 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        self.isActive = true // Hide splash screen
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("IncomingShareURL"))) { notification in
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
    
    private func processSharedRecord(_ sharedRecord: CKRecord) {
        guard let asset = sharedRecord["mapAsset"] as? CKAsset,
              let assetFileURL = asset.fileURL else {
            print("Failed to get CKAsset or assetFileURL from sharedRecord")
            return
        }
        print("Asset file URL: \(assetFileURL)")
        do {
            let data = try Data(contentsOf: assetFileURL)
            print("Loaded asset data of size: \(data.count) bytes")
            
            // (Optional) Diagnostic: print the header.
            let header = data.prefix(12).map { String(format: "%02x", $0) }.joined()
            print("Asset data header: \(header)")
            
            // Instead of trying to unarchive the data directly here,
            // write the raw data to the exact local file path that works.
            let roomName = (sharedRecord["roomName"] as? String) ?? "UnknownWorld"

            
            let localFilePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")

            // Write the data (overwrite any existing file)
            try data.write(to: localFilePath, options: .atomic)
            print("Shared asset data written to local file: \(localFilePath.path)")
            
            // Now, call your proven local load function.
            // For example, if you have:
            // worldManager.importWorldFromURL(_:)
            worldManager.importWorldFromURL(localFilePath)
            
        } catch {
            print("Error processing shared asset data: \(error.localizedDescription)")
        }
    }
    
    private func handleIncomingShareMetadata(_ metadata: CKShare.Metadata) {
        print("Handling incoming share metadata directly: \(metadata)")
        
        let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        acceptOperation.perShareCompletionBlock = { metadata, share, error in
            print("perShareCompletionBlock triggered")
            if let error = error {
                print("Error in perShareCompletionBlock: \(error.localizedDescription)")
                return
            }
            guard let share = share else {
                print("No share returned in perShareCompletionBlock")
                return
            }
            // Try to get the root record from the share.
            if let sharedRecord = share.value(forKey: "rootRecord") as? CKRecord {
                print("Fetched sharedRecord from share: \(sharedRecord.recordID)")
                self.processSharedRecord(sharedRecord)
            } else {
                // If the share doesn't include its root record, fetch it using the metadata's rootRecordID.
                if let shareMetadata = metadata as? CKShare.Metadata {
                    let rootRecordID = shareMetadata.rootRecordID
                    print("No rootRecord in share; fetching using rootRecordID: \(rootRecordID)")
                    CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                        if let fetchError = fetchError {
                            print("Error fetching root record: \(fetchError.localizedDescription)")
                        } else if let fetchedRecord = fetchedRecord {
                            print("Fetched root record via fetch: \(fetchedRecord.recordID)")
                            self.processSharedRecord(fetchedRecord)
                        } else {
                            print("Fetched record is nil")
                        }
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
        
        // Make sure it’s the right type (e.g., .arworld, .worldmap, etc.)
        guard url.pathExtension == "arworld" || url.pathExtension == "worldmap" else {
            print("Unknown file type: \(url.pathExtension)")
            return
        }
        
        
        // Hand off the URL to a helper in your WorldManager
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
                        name: Notification.Name("OpenWorldNotification"),
                        object: nil,
                        userInfo: ["worldName": worldName]
                    )
                    print("Selected world set to \(worldName) via Spotlight")
                }
            }
        } else if uniqueIdentifier.hasPrefix(itemPrefix) {
            // Remove the prefix, then split the remaining string at the first "."
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
                        name: Notification.Name("FindItemNotification"),
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
    
    
    // New function to accept CloudKit share URLs:
    private func handleIncomingShareURL(_ url: URL) {
        print("Incoming CloudKit share URL: \(url.absoluteString)")
        
        // Remove the fragment (if any) from the URL to avoid sandbox extension issues.
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
                // Try to get the root record directly from the share.
                if let sharedRecord = share.value(forKey: "rootRecord") as? CKRecord {
                    print("Fetched sharedRecord from share: \(sharedRecord.recordID)")
                    self.processSharedRecord(sharedRecord)
                } else {
                    // If not, fetch it using metadata's rootRecordID.
                    let rootRecordID = metadata.rootRecordID
                    print("No rootRecord in share; fetching using rootRecordID: \(rootRecordID)")
                    CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                        if let fetchError = fetchError {
                            print("Error fetching root record: \(fetchError.localizedDescription)")
                        } else if let fetchedRecord = fetchedRecord {
                            print("Fetched root record via fetch: \(fetchedRecord.recordID)")
                            self.processSharedRecord(fetchedRecord)
                        } else {
                            print("Fetched record is nil")
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

    
}
