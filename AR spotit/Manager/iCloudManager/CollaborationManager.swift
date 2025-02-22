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
    
    func fetchNewAnchors(for worldRecordID: CKRecord.ID, completion: @escaping ([CKRecord]) -> Void) {
        let publicDB = CKContainer.default().publicCloudDatabase
        // We store the world record's recordName in the anchor's "worldRecordName" field.
        let predicate = NSPredicate(format: "worldRecordName == %@", worldRecordID.recordName)
        let query = CKQuery(recordType: "Anchor", predicate: predicate)
        
        // For the public DB, using nil zone means the default zone.
        publicDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("❌ Error fetching anchors from public DB: \(error.localizedDescription)")
                completion([])
            } else {
                let count = records?.count ?? 0
                print("Fetched \(count) anchors from public DB for world record \(worldRecordID.recordName)")
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
        let publicRecordID = CKRecord.ID(recordName: "\(roomName)_Record")
        let publicDB = CKContainer.default().publicCloudDatabase
        
        // Attempt to fetch the world record from the public DB.
        publicDB.fetch(withRecordID: publicRecordID) { (existingRecord, error) in
            if let existingRecord = existingRecord {
                print("✅ Found existing public world record: \(existingRecord.recordID)")
                completion(existingRecord, nil)
                return
            }
            
            // If the error indicates the record doesn't exist, proceed.
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                // Query the private database for the world record.
                let predicate = NSPredicate(format: "roomName == %@", roomName)
                CloudKitService.shared.performQuery(recordType: self.recordType,
                                                    predicate: predicate,
                                                    zoneID: self.customZoneID,
                                                    desiredKeys: ["roomName", "mapAsset", "lastModified"]) { result in
                    switch result {
                    case .success(let records):
                        guard let privateRecord = records.first else {
                            print("No world record found in private DB for room: \(roomName)")
                            let error = NSError(domain: "com.yourapp.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "World record not found"])
                            completion(nil, error)
                            return
                        }
                        
                        // Create a new record in the public DB's default zone.
                        let publicRecord = CKRecord(recordType: self.recordType, recordID: publicRecordID)
                        
                        // Copy the room name.
                        publicRecord["roomName"] = privateRecord["roomName"]
                        
                        // Create a new CKAsset using the same file URL.
                        if let privateAsset = privateRecord["mapAsset"] as? CKAsset,
                           let fileURL = privateAsset.fileURL {
                            let newAsset = CKAsset(fileURL: fileURL)
                            publicRecord["mapAsset"] = newAsset
                        } else {
                            print("No valid mapAsset found in private record for room: \(roomName)")
                        }
                        
                        // Copy the lastModified field.
                        publicRecord["lastModified"] = privateRecord["lastModified"]
                        
                        
                        let pinHash = sha256(pin)
                        publicRecord["pinHash"] = pinHash as CKRecordValue
                        publicRecord["pinRequired"] = true as CKRecordValue
                        
                        
                        // Save the new public record.
                        publicDB.save(publicRecord) { savedRecord, error in
                            if let error = error {
                                print("❌ Error migrating world record to public DB: \(error.localizedDescription)")
                                completion(nil, error)
                            } else if let savedRecord = savedRecord {
                                
                                privateRecord["publicRecordName"] = savedRecord.recordID.recordName
                                privateRecord["pinRequired"] = true as CKRecordValue
                                privateRecord["pinHash"] = pinHash as CKRecordValue
                                self.privateDB.save(privateRecord) { _, privateError in
                                    if let privateError = privateError {
                                        print("❌ Error saving private record with publicRecordName: \(privateError.localizedDescription)")
                                    } else {
                                        print("✅ Updated private record with publicRecordName: \(savedRecord.recordID.recordName)")
                                    }
                                    completion(savedRecord, nil)
                                }
                                print("✅ Saved PIN hash: \(pinHash)")
                                // Show or share the PIN to User1 so they can pass it along to others
                                print("Your PIN is: \(pin)")
                                print("✅ Successfully migrated world record to public DB: \(savedRecord.recordID)")
                                completion(savedRecord, nil)
                            }
                        }
                        
                    case .failure(let error):
                        print("❌ Error querying private DB for world record: \(error.localizedDescription)")
                        completion(nil, error)
                    }
                }
            } else {
                // Some other error occurred while fetching from public DB.
                print("❌ Error fetching public record: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil, error)
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
            guard let publicRecord = publicRecord else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.createShareLink(for: roomName) { shareURL in
                // 3) Return the shareURL for the iMessage preview.
                completion(shareURL)
            }
            
            
        }
    }
}

