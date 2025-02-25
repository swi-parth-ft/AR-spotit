//
//  WorldManager 2.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-25.
//


import Foundation
import CloudKit
import UIKit

extension WorldManager {
    // MARK: - Shared Links Persistence
    
    private var sharedLinksFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Ensure the directory exists:
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("sharedLinks.json")
    }
    
    func loadSharedLinks() {
        let url = sharedLinksFileURL
        print("Loading shared links from: \(url.path)")
        guard let data = try? Data(contentsOf: url) else {
            print("No data found at \(url.path)")
            sharedLinks = []
            return
        }
        do {
            let links = try JSONDecoder().decode([SharedLinkModel].self, from: data)
            sharedLinks = links
            print("Loaded \(links.count) shared links")
        } catch {
            print("Error decoding shared links: \(error)")
            sharedLinks = []
        }
    }
    
    func saveSharedLinks() {
        let url = sharedLinksFileURL
        do {
            let data = try JSONEncoder().encode(sharedLinks)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Error saving shared links: \(error)")
        }
    }
    
    func addSharedLink(_ link: SharedLinkModel) {
        DispatchQueue.main.async {
            print(self.sharedLinks.count)
            self.sharedLinks.append(link)
            self.saveSharedLinks()
        }
    }
    
    func openSharedLink(_ sharedLink: SharedLinkModel) {
        print("Opening shared link for room: \(sharedLink.roomName)")
        let shareURL = sharedLink.shareURL

        // Clean the URL by removing any fragment
        guard var components = URLComponents(url: shareURL, resolvingAgainstBaseURL: false) else {
            print("❌ Invalid share URL.")
            return
        }
        components.fragment = nil
        guard let cleanedURL = components.url else {
            print("❌ Failed to construct a cleaned URL.")
            return
        }
        
        // Fetch the share metadata from CloudKit
        CKContainer.default().fetchShareMetadata(with: cleanedURL) { metadata, error in
            if let error = error {
                print("❌ Error fetching share metadata: \(error.localizedDescription)")
                return
            }
            guard let metadata = metadata else {
                print("❌ No share metadata found for URL: \(cleanedURL.absoluteString)")
                return
            }
            
            // Accept the share
            let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            acceptOperation.perShareCompletionBlock = { meta, share, error in
                if let error = error {
                    print("❌ Error accepting share: \(error.localizedDescription)")
                    return
                }
                guard let share = share else {
                    print("❌ No share returned from accept operation.")
                    return
                }
                
                // Determine the root record. This is similar to your existing flow.
                if let sharedRecord = share.value(forKey: "rootRecord") as? CKRecord {
                    DispatchQueue.main.async {
                        // Optionally, store this share in AppState if needed later.
                        AppState.shared.pendingShare = share
                        AppState.shared.pendingSharedRecord = sharedRecord
                        AppState.shared.pendingRoomName = sharedLink.roomName
                        // Start the collaborative session using the existing function.
                        WorldManager.shared.processIncomingSharedRecord(sharedRecord, withShare: share)
                    }
                } else {
                    // Fallback: fetch the root record using the metadata's rootRecordID.
                    let rootRecordID = metadata.rootRecordID
                    CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                        if let fetchError = fetchError {
                            print("❌ Error fetching root record: \(fetchError.localizedDescription)")
                        } else if let fetchedRecord = fetchedRecord {
                            DispatchQueue.main.async {
                                AppState.shared.pendingShare = share
                                AppState.shared.pendingSharedRecord = fetchedRecord
                                AppState.shared.pendingRoomName = sharedLink.roomName
                                WorldManager.shared.processIncomingSharedRecord(fetchedRecord, withShare: share)
                            }
                        }
                    }
                }
            }
            acceptOperation.acceptSharesResultBlock = { result in
                print("Accept shares operation result: \(result)")
            }
            CKContainer.default().add(acceptOperation)
        }
    }
    
    
    // MARK: - Process Incoming Shared Record (Update This Function)
    func processIncomingSharedRecord(_ sharedRecord: CKRecord, withShare share: CKShare) {
        let roomName = sharedRecord["roomName"] as? String ?? "Untitled"
        
        // Extract owner name using nameComponents or fallback to emailAddress.
        let ownerName: String = {
            if let nameComponents = share.owner.userIdentity.nameComponents {
                return PersonNameComponentsFormatter().string(from: nameComponents)
            } else if let email = share.owner.userIdentity.lookupInfo?.emailAddress {
                return email
            } else {
                return "Unknown"
            }
        }()
        
        // Get the share URL from the CKShare
        guard let shareURL = share.url else {
            print("Share URL not available")
            return
        }
        
        // Use a duplicate check based on roomName and ownerName (instead of shareURL)
        if !self.sharedLinks.contains(where: { $0.roomName == roomName && $0.ownerName == ownerName }) {
            // Retrieve a snapshot image from the ARWorldMap container (from the CKAsset)
            var snapshotFileName: String? = nil
            if let asset = sharedRecord["mapAsset"] as? CKAsset,
               let assetFileURL = asset.fileURL,
               let data = try? Data(contentsOf: assetFileURL),
               let container = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data),
               let snapshotData = container.imageData {
                // Save snapshot image locally in Application Support.
                // Using roomName in the file name might cause overwrites if the room is shared multiple times.
                // You can add additional identifiers if needed.
                let fileName = "\(roomName)_sharedSnapshot.png"
                let snapshotURL = WorldModel.appSupportDirectory.appendingPathComponent(fileName)
                do {
                    try snapshotData.write(to: snapshotURL, options: .atomic)
                    snapshotFileName = fileName
                    print("Saved shared snapshot to \(snapshotURL.path)")
                } catch {
                    print("Error saving shared snapshot: \(error.localizedDescription)")
                }
            }
            
            // Create a new SharedLinkModel instance and persist it.
            let newSharedLink = SharedLinkModel(
                id: UUID(),
                shareURL: shareURL,
                roomName: roomName,
                ownerName: ownerName,
                snapshotFileName: snapshotFileName,
                dateReceived: Date()
            )
            addSharedLink(newSharedLink)
        } else {
            print("Shared link for room \(roomName) from \(ownerName) already exists, skipping save.")
        }
        
        // Continue with your existing flow:
        DispatchQueue.main.async {
            self.sharedZoneID = share.recordID.zoneID
            print("Shared zone ID set to: \(self.sharedZoneID!)")
            AppState.shared.publicRecordName = sharedRecord["publicRecordName"] as? String ?? ""
            AppState.shared.isiCloudShare = true
        }
        
        // Start the collaborative session as before.
        self.startCollaborativeSession(with: sharedRecord, roomName: roomName)
        
        // Update pending AppState for the open/save or PIN sheets.
        guard let asset = sharedRecord["mapAsset"] as? CKAsset,
              let assetFileURL = asset.fileURL else {
            print("❌ Failed to get CKAsset or assetFileURL")
            return
        }
        DispatchQueue.main.async {
            AppState.shared.pendingSharedRecord = sharedRecord
            AppState.shared.pendingAssetFileURL = assetFileURL
            AppState.shared.pendingRoomName = roomName
            let pinRequired = sharedRecord["pinRequired"] as? Bool ?? false
            if pinRequired {
                print("🔒 PIN is required. Showing PIN sheet...")
                AppState.shared.isShowingCollaborationChoiceSheet = true
            } else {
                print("🔓 No PIN required. Showing open/save sheet...")
                AppState.shared.isShowingOpenSaveSheet = true
            }
        }
    }
    
    
    func deleteSharedLink(_ link: SharedLinkModel) {
            // Delete the snapshot file from disk if it exists.
            if let snapshotFileName = link.snapshotFileName {
                let snapshotURL = WorldModel.appSupportDirectory.appendingPathComponent(snapshotFileName)
                do {
                    try FileManager.default.removeItem(at: snapshotURL)
                    print("Deleted snapshot at \(snapshotURL.path)")
                } catch {
                    print("Error deleting snapshot: \(error.localizedDescription)")
                }
            }
            
            // Remove the link from the sharedLinks array.
            if let index = self.sharedLinks.firstIndex(where: { $0.id == link.id }) {
                self.sharedLinks.remove(at: index)
                print("Deleted shared link for room: \(link.roomName)")
            } else {
                print("Shared link not found in the array.")
            }
            
            // Save the updated sharedLinks persistently.
            self.saveSharedLinks()
        }
}
