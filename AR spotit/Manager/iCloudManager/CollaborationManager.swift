//
//  CollaborationManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-18.
//

import Foundation
import CloudKit
import ARKit
import Drops


extension iCloudManager {
    // MARK: - iCloud Share Link Functions
    
    func createShareLink(for roomName: String, completion: @escaping (URL?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: ["share"]) { result in
            switch result {
            case .success(let records):
                guard let record = records.first else {
                    print("⚠️ No record found for \(roomName).")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let fetchOp = CKFetchRecordsOperation(recordIDs: [record.recordID])
                fetchOp.desiredKeys = ["share"]
                var fetchedRecords: [CKRecord.ID: CKRecord] = [:]
                fetchOp.perRecordResultBlock = { [weak self] (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
                    guard let _ = self else { return }
                    switch result {
                    case .success(let fetchedRecord):
                        fetchedRecords[recordID] = fetchedRecord
                    case .failure(let error):
                        print("Error fetching record \(recordID): \(error.localizedDescription)")
                    }
                }
                fetchOp.fetchRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        guard let fetchedRecord = fetchedRecords[record.recordID] else {
                            print("❌ Re-fetch failed; record not found.")
                            DispatchQueue.main.async { completion(nil) }
                            return
                        }
                        if let shareValue = fetchedRecord["share"] {
                            if let share = shareValue as? CKShare {
                                print("✅ Found existing CKShare: \(share)")
                                DispatchQueue.main.async { completion(share.url) }
                            } else if let shareRef = shareValue as? CKRecord.Reference {
                                print("✅ Found share reference, fetching full CKShare...")
                                self.fetchShareRecord(from: shareRef, completion: completion)
                            } else {
                                print("❌ Share value is not CKShare or CKRecord.Reference.")
                                DispatchQueue.main.async { completion(nil) }
                            }
                        } else {
                            self.createShare(for: fetchedRecord, roomName: roomName, completion: completion)
                        }
                    case .failure(let error):
                        print("❌ Error re-fetching record: \(error.localizedDescription)")
                        DispatchQueue.main.async { completion(nil) }
                    }
                }
                self.privateDB.add(fetchOp)
            case .failure(let error):
                print("❌ Error querying record: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    func fetchShareRecord(from shareReference: CKRecord.Reference, completion: @escaping (URL?) -> Void) {
        let shareRecordID = shareReference.recordID
        let fetchOp = CKFetchRecordsOperation(recordIDs: [shareRecordID])
        fetchOp.desiredKeys = ["share"]
        var fetchedRecords: [CKRecord.ID: CKRecord] = [:]
        fetchOp.perRecordResultBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                fetchedRecords[recordID] = record
            case .failure(let error):
                print("Error fetching record \(recordID): \(error.localizedDescription)")
            }
        }
        fetchOp.fetchRecordsResultBlock = {  result in
            
            switch result {
            case .success:
                guard let shareRecord = fetchedRecords[shareRecordID] as? CKShare else {
                    print("⚠️ Could not cast fetched record to CKShare.")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                print("✅ Successfully fetched CKShare: \(shareRecord)")
                DispatchQueue.main.async { completion(shareRecord.url) }
            case .failure(let error):
                print("❌ Error fetching share record: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
        self.privateDB.add(fetchOp)
    }
    
    func createShare(for record: CKRecord, roomName: String, completion: @escaping (URL?) -> Void) {
        print("🔍 Creating share for record: \(record.recordID)")
        print("Record zone: \(record.recordID.zoneID) | Expected custom zone: \(self.customZoneID)")
        if record.recordID.zoneID != self.customZoneID {
            print("❌ Record is not in the custom zone. Cannot create share.")
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = roomName as CKRecordValue
        
        let snapshotPath = WorldModel.appSupportDirectory
            .appendingPathComponent("\(roomName)_snapshot.png")
        
        if FileManager.default.fileExists(atPath: snapshotPath.path),
           let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
            if let jpegData = uiImage.jpegData(compressionQuality: 0.3) {
                share[CKShare.SystemFieldKey.thumbnailImageData] = jpegData
            }
        }
        
        //  record["share"] = share
        
        
        share.publicPermission = .readWrite
        self.subscribeToWorldUpdates(for: roomName)
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
        modifyOp.isAtomic = true
        modifyOp.savePolicy = .allKeys
        modifyOp.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecord.ID]?, error: Error?) in
            if let error = error {
                print("❌ Error saving share: \(error.localizedDescription)")
                self.privateDB.fetch(withRecordID: record.recordID) { fetchedRecord, error in
                    if let error = error {
                        print("❌ Error fetching record in fallback: \(error.localizedDescription)")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    guard let fetchedRecord = fetchedRecord else {
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    if let shareValue = fetchedRecord["share"] {
                        if let existingShare = shareValue as? CKShare {
                            print("✅ Fallback: Found existing share after re-fetch.")
                            DispatchQueue.main.async { completion(existingShare.url) }
                        } else if let shareRef = shareValue as? CKRecord.Reference {
                            print("✅ Fallback: Found share reference after re-fetch; fetching full CKShare...")
                            self.fetchShareRecord(from: shareRef, completion: completion)
                        } else {
                            print("❌ Fallback: Share value is not a CKShare or CKRecord.Reference.")
                            DispatchQueue.main.async { completion(nil) }
                        }
                    } else {
                        DispatchQueue.main.async { completion(nil) }
                    }
                }
            } else if let savedRecords = savedRecords, !savedRecords.isEmpty {
                if let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare {
                    print("✅ CKShare created successfully: \(savedShare)")
                    // After your CKShare is successfully created...
                    DispatchQueue.main.async {
                        WorldManager.shared.sharedZoneID = share.recordID.zoneID
                    }
                    DispatchQueue.main.async { completion(savedShare.url) }
                } else {
                    print("⚠️ CKShare not found in saved records.")
                    DispatchQueue.main.async { completion(nil) }
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
        self.privateDB.add(modifyOp)
    }
    
    // MARK: - Subscription and Custom Zone
    func subscribeToWorldUpdates(for roomName: String) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let subscriptionID = "\(roomName)_subscription"
        let subscription = CKQuerySubscription(recordType: recordType,
                                               predicate: predicate,
                                               subscriptionID: subscriptionID,
                                               options: [.firesOnRecordUpdate])
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        self.privateDB.save(subscription) {  savedSubscription, error in
            
            if let error = error {
                print("❌ Error creating subscription for \(roomName): \(error.localizedDescription)")
            } else if let savedSubscription = savedSubscription {
                print("✅ Successfully subscribed to updates for \(roomName): \(savedSubscription)")
            }
        }
    }
    
    func saveAnchor(_ anchor: ARAnchor, for roomName: String, worldRecord: CKRecord, completion: @escaping (Error?) -> Void) {
        // Use the public database
        let publicDB = CKContainer.default().publicCloudDatabase
        
        // Create a record in the public default zone (do not specify a custom zone)
        let recordID = CKRecord.ID(recordName: UUID().uuidString) // Defaults to public DB’s default zone
        let anchorRecord = CKRecord(recordType: "Anchor", recordID: recordID)
        
        anchorRecord["roomName"] = roomName as CKRecordValue
        if let name = anchor.name {
            anchorRecord["name"] = name as CKRecordValue
            print("Saving anchor with name: \(name)")
        }
        let transformData = withUnsafeBytes(of: anchor.transform) { Data($0) }
        anchorRecord["transform"] = transformData as CKRecordValue
        
        // Create a reference to the world record.
        // Note: The worldRecord must also be in the public DB’s default zone.
        let reference = CKRecord.Reference(record: worldRecord, action: .deleteSelf)
        anchorRecord["worldReference"] = reference
        print("[DEBUG] saveAnchor: Using worldRecord.recordID = \(worldRecord.recordID.recordName)")
        
        anchorRecord["worldRecordName"] = worldRecord.recordID.recordName as CKRecordValue
        print("[DEBUG] anchorRecord[\"worldRecordName\"] = \(worldRecord.recordID.recordName)")
        
        publicDB.save(anchorRecord) { record, error in
            if let error = error {
                print("❌ Error saving anchor to public DB: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ Anchor saved successfully to public DB.")
                completion(nil)
            }
        }
    }
    
    func deleteAnchor(withRecordID recordID: CKRecord.ID, completion: @escaping (Error?) -> Void) {
        // Using the public database if anchors are saved in the public default zone.
        let publicDB = CKContainer.default().publicCloudDatabase
        publicDB.delete(withRecordID: recordID) { deletedRecordID, error in
            if let error = error {
                print("❌ Error deleting anchor from CloudKit: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ Anchor deleted successfully from CloudKit.")
                completion(nil)
            }
        }
    }
    
    func fetchNewAnchors(for recordName: String, completion: @escaping ([CKRecord]) -> Void) {
        let publicDB = CKContainer.default().publicCloudDatabase
        // We store the world record's recordName in the anchor's "worldRecordName" field.
        let predicate = NSPredicate(format: "worldRecordName == %@", recordName)
        let query = CKQuery(recordType: "Anchor", predicate: predicate)
        
        // For the public DB, using nil zone means the default zone.
        publicDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("❌ Error fetching anchors from public DB: \(error.localizedDescription)")
                completion([])
            } else {
                let count = records?.count ?? 0
                print("Fetched \(count) anchors from public DB for world record \(recordName)")
                completion(records ?? [])
            }
        }
    }
    
    
    func subscribeToAnchorUpdates(for worldRecordID: CKRecord.ID) {
        // Create a predicate that fetches Anchor records related to the current world.
        let predicate = NSPredicate(format: "worldReference == %@", CKRecord.Reference(recordID: worldRecordID, action: .none))
        let subscription = CKQuerySubscription(recordType: "Anchor",
                                               predicate: predicate,
                                               subscriptionID: "AnchorSubscription-\(worldRecordID.recordName)",
                                               options: [.firesOnRecordCreation, .firesOnRecordUpdate])
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDB.save(subscription) { subscription, error in
            if let error = error {
                print("❌ Error subscribing to anchor updates: \(error.localizedDescription)")
            } else {
                print("✅ Subscribed to anchor updates for world \(worldRecordID.recordName)")
            }
        }
    }
    
    func migrateWorldRecordToPublic(roomName: String, pin: String, completion: @escaping (CKRecord?, Error?) -> Void) {
        let publicDB = CKContainer.default().publicCloudDatabase
        
        // 1) Query the private DB for the record by "roomName" (same as your existing code)
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: self.recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: ["roomName", "mapAsset", "lastModified", "publicRecordName", "pinRequired", "pinHash"]) { queryResult in
            switch queryResult {
            case .failure(let error):
                print("❌ Error querying private DB for world record: \(error.localizedDescription)")
                completion(nil, error)
                
            case .success(let privateRecords):
                guard let privateRecord = privateRecords.first else {
                    print("⚠️ No world record found in private DB for room: \(roomName)")
                    let notFoundError = NSError(domain: "com.yourapp.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "World record not found"])
                    completion(nil, notFoundError)
                    return
                }
                
                // 2) Check if we already have a "publicRecordName" from a prior migration
                var publicRecordName = privateRecord["publicRecordName"] as? String
                
                // If nil, create a brand new one
                if publicRecordName == nil {
                    publicRecordName = UUID().uuidString
                }
                
                // Then build the recordID from that stable string
                let publicRecordID = CKRecord.ID(recordName: publicRecordName!)
                
                // 3) Attempt to fetch from the public DB
                publicDB.fetch(withRecordID: publicRecordID) { (existingRecord, error) in
                    if let existingRecord = existingRecord {
                        // => We already have a public record with this ID => update it or just return
                        print("✅ Found existing public world record: \(existingRecord.recordID)")
                        
                        // If you want, you can update fields or do nothing:
                        existingRecord["pinHash"] = sha256(pin) as CKRecordValue
                        existingRecord["pinRequired"] = true as CKRecordValue
                        publicDB.save(existingRecord) { updated, updateError in
                            completion(updated, updateError)
                        }
                        return
                    }
                    
                    // If error indicates "not found", we create a new record
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        // 4) Create a new record in the public DB’s default zone
                        let publicRecord = CKRecord(recordType: self.recordType, recordID: publicRecordID)
                        
                        // Copy fields from the private record
                        publicRecord["roomName"] = privateRecord["roomName"]
                        if let privateAsset = privateRecord["mapAsset"] as? CKAsset,
                           let fileURL = privateAsset.fileURL {
                            publicRecord["mapAsset"] = CKAsset(fileURL: fileURL)
                        }
                        publicRecord["lastModified"] = privateRecord["lastModified"]
                        
                        let pinHash = sha256(pin)
                        publicRecord["pinHash"] = pinHash as CKRecordValue
                        publicRecord["pinRequired"] = true as CKRecordValue
                        
                        // Save the new public record
                        publicDB.save(publicRecord) { savedRecord, error in
                            if let error = error {
                                print("❌ Error migrating record to public DB: \(error.localizedDescription)")
                                completion(nil, error)
                            } else if let savedRecord = savedRecord {
                                print("✅ Successfully migrated record to public DB: \(savedRecord.recordID)")
                                
                                // 5) Store the stable name back into the private record so we can remove collisions
                                privateRecord["publicRecordName"] = savedRecord.recordID.recordName
                                privateRecord["pinRequired"] = true as CKRecordValue
                                privateRecord["pinHash"] = pinHash as CKRecordValue
                                if let room = privateRecord["roomName"] as? String {
                                            if let idx = self.worldManager?.savedWorlds.firstIndex(where: { $0.name == room }) {
                                                DispatchQueue.main.async {
                                                    self.worldManager?.savedWorlds[idx].publicRecordName = savedRecord.recordID.recordName
                                                    self.worldManager?.saveWorldList()
                                                    self.worldManager?.syncLocalWorldsToCloudKit(roomName: roomName)
                                                }
                                               
                                                
                                            }
                                        }
                                // Save the updated private record
                                self.privateDB.save(privateRecord) { _, privateError in
                                    if let privateError = privateError {
                                        print("❌ Error saving private record with publicRecordName: \(privateError.localizedDescription)")
                                    } else {
                                        print("✅ Updated private record with publicRecordName: \(savedRecord.recordID.recordName)")
                                    }
                                    // Return the new public record
                                    completion(savedRecord, nil)
                                }
                                
                                // Show or share the PIN to User1 so they can pass it along
                                print("✅ Saved PIN hash: \(pinHash)")
                                print("Your PIN is: \(pin)")
                                
                            } else {
                                // no error, but no savedRecord => weird
                                completion(nil, nil)
                            }
                        }
                    } else {
                        // Some other fetch error
                        print("❌ Error fetching from public DB: \(error?.localizedDescription ?? "Unknown error")")
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    
    func createCollabLink(for roomName: String, with pin: String, completion: @escaping (URL?) -> Void) {
        // Migrate the world record from the private DB to the public DB.
        self.migrateWorldRecordToPublic(roomName: roomName, pin: pin) { publicRecord, error in
            if let error = error {
                print("Migration error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard publicRecord != nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.createShareLink(for: roomName) { shareURL in
                // 3) Return the shareURL for the iMessage preview.
                completion(shareURL)
            }
            
            
        }
    }
    
    
    func removeCollaboration(for roomName: String, completion: @escaping (Error?) -> Void) {
        // 1) Fetch the private world record for this roomName in the custom zone.
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: ["publicRecordName", "share", "pinRequired", "pinHash"]) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("❌ Error fetching private record for \(roomName): \(error.localizedDescription)")
                DispatchQueue.main.async { completion(error) }
                
            case .success(let records):
                guard let privateRecord = records.first else {
                    print("⚠️ No private record found for \(roomName). Nothing to remove.")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // Store any existing public record name; we’ll delete that from the public DB if it exists.
                let publicRecordName = privateRecord["publicRecordName"] as? String
                
                // 2) If we have a public record, delete it + all related anchor records from the public DB.
                self.deletePublicRecordAndAnchorsIfNeeded(publicRecordName: publicRecordName) { error in
                    if let error = error {
                        print("❌ Error deleting public record or anchors: \(error.localizedDescription)")
                        // Continue even if public deletion failed, since we still want to fix local metadata.
                    }
                    
                   
                    // 3) Remove share + PIN fields from the private record, then save it.
                    privateRecord["share"] = nil
                    privateRecord["pinRequired"] = nil
                    privateRecord["pinHash"] = nil
                    privateRecord["publicRecordName"] = nil
                    let modifyOp = CKModifyRecordsOperation(recordsToSave: [privateRecord], recordIDsToDelete: nil)
                    modifyOp.savePolicy = .allKeys
                    modifyOp.modifyRecordsCompletionBlock = { _, _, saveError in
                        if let saveError = saveError {
                            print("❌ Error removing share/PIN from private record: \(saveError.localizedDescription)")
                        } else {
                            print("✅ Successfully removed collaboration fields for \(roomName) in private record.")
                        }
                        
                        // 4) Update local metadata so isCollaborative = false, pin = nil, then sync.
                        DispatchQueue.main.async {
                            if let index = self.worldManager?.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                                self.worldManager?.savedWorlds[index].isCollaborative = false
                                self.worldManager?.savedWorlds[index].pin = nil
                                self.worldManager?.saveWorldList()
                                // Optionally sync updated metadata to CloudKit again
                                self.worldManager?.syncLocalWorldsToCloudKit(roomName: roomName)
                            }
                            completion(saveError)
                        }
                    }
                    self.privateDB.add(modifyOp)
                }
            }
        }
        
        
        
    }

    // MARK: - Helper function to delete the public record and all related anchors
    func deletePublicRecordAndAnchorsIfNeeded(publicRecordName: String?, completion: @escaping (Error?) -> Void) {
        guard let publicRecordName = publicRecordName else {
            // No public record name => no action needed
            completion(nil)
            return
        }
        
        let publicDB = CKContainer.default().publicCloudDatabase
        let publicRecordID = CKRecord.ID(recordName: publicRecordName) // default (public) zone
        
        // First, delete any anchors in the public DB referencing this world record.
        let predicate = NSPredicate(format: "worldRecordName == %@", publicRecordName)
        let query = CKQuery(recordType: "Anchor", predicate: predicate)
        publicDB.perform(query, inZoneWith: nil) { anchorRecords, anchorError in
            if let anchorError = anchorError {
                print("⚠️ Error fetching anchors for \(publicRecordName): \(anchorError.localizedDescription)")
            }
            
            // Delete all anchor records referencing this public record
            let anchorRecordIDs = anchorRecords?.map { $0.recordID } ?? []
            let deleteAnchorsOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: anchorRecordIDs)
            deleteAnchorsOp.modifyRecordsCompletionBlock = { _, deletedIDs, anchorDeleteError in
                if let anchorDeleteError = anchorDeleteError {
                    print("⚠️ Error deleting anchor records: \(anchorDeleteError.localizedDescription)")
                } else if let deletedIDs = deletedIDs, !deletedIDs.isEmpty {
                    print("✅ Deleted \(deletedIDs.count) anchor(s) referencing \(publicRecordName)")
                }
                
                // Finally, delete the public world record itself
                publicDB.delete(withRecordID: publicRecordID) { _, publicDeleteError in
                    if let publicDeleteError = publicDeleteError {
                        print("❌ Error deleting public world record \(publicRecordName): \(publicDeleteError.localizedDescription)")
                    } else {
                        print("✅ Public world record \(publicRecordName) deleted.")
                    }
                    completion(publicDeleteError)
                }
                
                
              
            }
            publicDB.add(deleteAnchorsOp)
        }
    }
}


