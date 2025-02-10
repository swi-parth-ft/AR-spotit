//
//  iCloudManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-16.
//

import Foundation
import CloudKit
import ARKit
import Drops
let CKErrorPartialErrorsByItemIDKey = "CKErrorPartialErrorsByItemIDKey"
typealias FetchResult = Result<
    (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
     queryCursor: CKQueryOperation.Cursor?),
    Error
>

class iCloudManager {
    private let recordType = "ARWorldMapRecord"
    // Custom zone is required for sharing in the private database.
    let customZoneID = CKRecordZone.ID(zoneName: "ARWorldMapZone", ownerName: CKCurrentUserDefaultName)
    private let privateDB = CKContainer.default().privateCloudDatabase
    weak var worldManager: WorldManager? // Use a weak reference to avoid circular dependency
    
    init(worldManager: WorldManager?) {
        self.worldManager = worldManager
        // Ensure the custom zone exists before any operations.
        createCustomZoneIfNeeded()
    }
    
    // MARK: - Upload ARWorldMap
    
    func uploadWorldMap(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            // Use the same file path that your local load uses:
            let localFilePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
            do {
                // Write data to the local file path
                try data.write(to: localFilePath)
            } catch {
                print("Error writing to local file path: \(error.localizedDescription)")
                completion?()
                return
            }
            
            let predicate = NSPredicate(format: "roomName == %@", roomName)
            let query = CKQuery(recordType: self.recordType, predicate: predicate)
            
            // Query in the custom zone.
            self.privateDB.perform(query, inZoneWith: self.customZoneID) { records, error in
                if let error = error {
                    print("Error querying CloudKit: \(error.localizedDescription)")
//                    try? FileManager.default.removeItem(at: localFilePath)
                    completion?()
                    return
                }
                
                if let record = records?.first { // Record exists, update it.
                    record["mapAsset"] = CKAsset(fileURL: localFilePath)
                    record["lastModified"] = lastModified as CKRecordValue
                    
                    self.privateDB.save(record) { _, error in
//                        try? FileManager.default.removeItem(at: localFilePath)
                        if let error = error {
                            print("Error updating record in CloudKit: \(error.localizedDescription)")
                        } else {
                            print("Updated \(roomName) in CloudKit.")
                        }
                        completion?()
                    }
                } else { // Record doesn't exist, create a new one.
                    let recordID = CKRecord.ID(recordName: "\(roomName)_Record", zoneID: self.customZoneID)
                    let record = CKRecord(recordType: self.recordType, recordID: recordID)
                    record["roomName"] = roomName as CKRecordValue
                    record["mapAsset"] = CKAsset(fileURL: localFilePath)
                    record["lastModified"] = lastModified as CKRecordValue
                    
                    self.privateDB.save(record) { _, error in
//                        try? FileManager.default.removeItem(at: localFilePath)
                        if let error = error {
                            print("Error saving to CloudKit: \(error.localizedDescription)")
                        } else {
                            print("Uploaded \(roomName) to CloudKit in custom zone.")
                        }
                        completion?()
                    }
                }
            }
        }
    }
    // MARK: - Fetch World Names
    
    func fetchWorldNames(completion: @escaping ([WorldModel]) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        // Query using the custom zone.
        privateDB.fetch(withQuery: query, inZoneWith: self.customZoneID, desiredKeys: ["roomName", "lastModified"], resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                var fetchedWorlds: [WorldModel] = []
                for (_, recordResult) in matchedResults {
                    switch recordResult {
                    case .success(let record):
                        if let roomName = record["roomName"] as? String,
                           let lastModified = record["lastModified"] as? Date {
                            fetchedWorlds.append(WorldModel(name: roomName, lastModified: lastModified))
                        }
                    case .failure(let error):
                        print("Error fetching record: \(error.localizedDescription)")
                    }
                }
                completion(fetchedWorlds)
            case .failure(let error):
                print("Error fetching world names from CloudKit: \(error.localizedDescription)")
                Drops.show("Error fetching world names from iCloud")
                completion([])
            }
        }
    }
    
    // MARK: - Load World Map
    
    func loadWorldMap(roomName: String, completion: @escaping (Data?, ARWorldMap?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        // Query in the custom zone.
        privateDB.perform(query, inZoneWith: self.customZoneID) { records, error in
            if let error = error {
                print("Error querying CloudKit: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            guard let record = records?.first,
                  let asset = record["mapAsset"] as? CKAsset,
                  let assetFileURL = asset.fileURL else {
                print("No valid record or asset for \(roomName).")
                completion(nil, nil)
                return
            }
            do {
                let data = try Data(contentsOf: assetFileURL)
                if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                    completion(data, container.map) // Return BOTH raw data + ARWorldMap
                } else {
                    print("Failed to unarchive ARWorldMapContainer from CloudKit.")
                    completion(nil, nil)
                }
                print("Local archive hash: \(sha256Hash(of: data))")
            } catch {
                print("Error loading CloudKit asset: \(error.localizedDescription)")
                completion(nil, nil)
            }
        }
    }
    
    // MARK: - Delete World
    
    func deleteWorld(roomName: String, completion: @escaping (Error?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        // First, try to find the record in the custom zone.
        privateDB.perform(query, inZoneWith: self.customZoneID) { [weak self] records, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error performing query in custom zone: \(error.localizedDescription)")
            }
            
            if let records = records, !records.isEmpty {
                // Found records in custom zone; proceed to delete.
                let recordIDs = records.map { $0.recordID }
                let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                deleteOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                    if let error = error {
                        print("Error deleting records from custom zone: \(error.localizedDescription)")
                        DispatchQueue.main.async { completion(error) }
                    } else {
                        print("World \(roomName) deleted from custom zone.")
                        DispatchQueue.main.async { completion(nil) }
                    }
                }
                self.privateDB.add(deleteOp)
            } else {
                // No records in custom zone. Try the default zone.
                print("No records found in custom zone for \(roomName), trying default zone.")
                self.privateDB.perform(query, inZoneWith: nil) { records, error in
                    if let error = error {
                        print("Error performing query in default zone: \(error.localizedDescription)")
                        DispatchQueue.main.async { completion(error) }
                        return
                    }
                    guard let records = records, !records.isEmpty else {
                        print("No records found for \(roomName) in default zone.")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    
                    let recordIDs = records.map { $0.recordID }
                    let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                    deleteOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                        if let error = error {
                            print("Error deleting records from default zone: \(error.localizedDescription)")
                            DispatchQueue.main.async { completion(error) }
                        } else {
                            print("World \(roomName) deleted from default zone.")
                            DispatchQueue.main.async { completion(nil) }
                        }
                    }
                    self.privateDB.add(deleteOp)
                }
            }
        }
    }
    // MARK: - Delete All Records
    
    func deleteAllRecords(completion: @escaping (Error?) -> Void) {
        let recordTypes = ["ARWorldMapRecord", "WorldListRecord"] // Add all your record types here
        let dispatchGroup = DispatchGroup()
        var finalError: Error?
        
        for recordType in recordTypes {
            dispatchGroup.enter()
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            
            // For ARWorldMapRecord, use the custom zone; otherwise, use nil.
            let zoneID: CKRecordZone.ID? = (recordType == "ARWorldMapRecord") ? customZoneID : nil
            
            privateDB.fetch(withQuery: query, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
                
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
                    
                    self.privateDB.add(deleteOperation)
                    
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
    
    // MARK: - Fetch Last Modified
    
    func fetchLastModified(for roomName: String, completion: @escaping (Date?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: self.recordType, predicate: predicate)
        
        // Use the custom zone.
        privateDB.perform(query, inZoneWith: self.customZoneID) { records, error in
            if let error = error {
                print("❌ fetchLastModified error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let record = records?.first,
                  let lastModified = record["lastModified"] as? Date else {
                completion(nil)
                return
            }
            
            completion(lastModified)
        }
    }
}







// Manually define this key if not provided by your SDK:

extension iCloudManager {
    
    // MARK: – Public Function to Create or Reuse a Share Link
    func createShareLink(for roomName: String, completion: @escaping (URL?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        print("🔍 Starting query for room: \(roomName)")
        
        // Use the older perform(_:inZoneWith:) API to query records in the custom zone.
        self.privateDB.perform(query, inZoneWith: self.customZoneID) { records, error in
            if let error = error {
                print("❌ Error querying record: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let records = records, let record = records.first else {
                print("⚠️ No record found for \(roomName).")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // Re-fetch the record to ensure system fields (like "share") are available.
            let fetchOp = CKFetchRecordsOperation(recordIDs: [record.recordID])
            fetchOp.desiredKeys = ["share"]
            fetchOp.fetchRecordsCompletionBlock = { recordsByRecordID, error in
                if let error = error {
                    print("❌ Error re-fetching record: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                guard let recordsByRecordID = recordsByRecordID,
                      let fetchedRecord = recordsByRecordID[record.recordID] else {
                    print("❌ Re-fetch failed; record not found.")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                // Check if the record already has a share.
                if let shareValue = fetchedRecord["share"] {
                    if let share = shareValue as? CKShare {
                        print("✅ Found existing CKShare: \(share)")
                        DispatchQueue.main.async { completion(share.url) }
                        return
                    } else if let shareRef = shareValue as? CKRecord.Reference {
                        print("✅ Found share reference, fetching full CKShare...")
                        self.fetchShareRecord(from: shareRef, completion: completion)
                        return
                    }
                }
                // No share exists – create one.
                self.createShare(for: fetchedRecord, roomName: roomName, completion: completion)
            }
            self.privateDB.add(fetchOp)
        }
    }
    
    // MARK: – Private Helper: Fetch Full CKShare from a Reference
    func fetchShareRecord(from shareReference: CKRecord.Reference, completion: @escaping (URL?) -> Void) {
        let shareRecordID = shareReference.recordID
        let fetchOp = CKFetchRecordsOperation(recordIDs: [shareRecordID])
        fetchOp.desiredKeys = ["share"]
        fetchOp.fetchRecordsCompletionBlock = { recordsByRecordID, error in
            if let error = error {
                print("❌ Error fetching share record: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let recordsByRecordID = recordsByRecordID,
                  let shareRecord = recordsByRecordID[shareRecordID] as? CKShare else {
                print("⚠️ Could not cast fetched record to CKShare.")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            print("✅ Successfully fetched CKShare: \(shareRecord)")
            DispatchQueue.main.async { completion(shareRecord.url) }
        }
        self.privateDB.add(fetchOp)
    }
    
    // MARK: – Private Helper: Create a CKShare for a Record
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
        share.publicPermission = .readOnly

        self.subscribeToWorldUpdates(for: roomName)
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
        modifyOp.isAtomic = true
        modifyOp.savePolicy = .allKeys
        modifyOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let error = error {
                print("❌ Error saving share: \(error.localizedDescription)")
                // Fallback: fetch the record using the older API.
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
                // savedRecords is an array of CKRecord
                if let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare {
                    print("✅ CKShare created successfully: \(savedShare)")
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
    
    // MARK: – Fully Implemented World Update Subscription using the older API
    func subscribeToWorldUpdates(for roomName: String) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let subscriptionID = "\(roomName)_subscription"
        let subscription = CKQuerySubscription(recordType: recordType,
                                               predicate: predicate,
                                               subscriptionID: subscriptionID,
                                               options: [.firesOnRecordUpdate])
        // In older SDKs, CKNotificationInfo is used.
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        // The older save(completionBlock:) API uses (CKSubscription?, Error?) -> Void.
        self.privateDB.save(subscription) { savedSubscription, error in
            if let error = error {
                print("❌ Error creating subscription for \(roomName): \(error.localizedDescription)")
            } else if let savedSubscription = savedSubscription {
                print("✅ Successfully subscribed to updates for \(roomName): \(savedSubscription)")
            }
        }
    }
    
    func createCustomZoneIfNeeded() {
        let zone = CKRecordZone(zoneID: customZoneID)
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        op.modifyRecordZonesCompletionBlock = { savedZones, deletedZoneIDs, error in
            if let error = error {
                print("Error creating custom zone: \(error.localizedDescription)")
            } else {
                print("Custom zone created or already exists.")
            }
        }
        privateDB.add(op)
    }
}
