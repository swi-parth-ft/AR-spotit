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

class iCloudManager {
    private let recordType = "ARWorldMapRecord"
    let customZoneID = CKRecordZone.ID(zoneName: "ARWorldMapZone", ownerName: CKCurrentUserDefaultName)
    private let privateDB = CKContainer.default().privateCloudDatabase
    weak var worldManager: WorldManager?
    
    init(worldManager: WorldManager?) {
        self.worldManager = worldManager
        createCustomZoneIfNeeded()
    }
    
    // MARK: - Upload ARWorldMap
    func uploadWorldMap(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
          
            let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Error writing to local file path: \(error.localizedDescription)")
                completion?()
                return
            }
            
            let predicate = NSPredicate(format: "roomName == %@", roomName)
            CloudKitService.shared.performQuery(recordType: self.recordType,
                                                predicate: predicate,
                                                zoneID: self.customZoneID,
                                                desiredKeys: ["roomName", "lastModified"]) {  result in
           
                switch result {
                case .success(let records):
                    if let record = records.first {
                        record["mapAsset"] = CKAsset(fileURL: fileURL)
                        record["lastModified"] = lastModified as CKRecordValue
                        CloudKitService.shared.saveRecord(record) { saveResult in
                            switch saveResult {
                            case .success:
                                print("Updated \(roomName) in CloudKit.")
                            case .failure(let error):
                                print("Error updating record in CloudKit: \(error.localizedDescription)")
                            }
                            completion?()
                        }
                    } else {
                        let recordID = CKRecord.ID(recordName: "\(roomName)_Record", zoneID: self.customZoneID)
                        let newRecord = CKRecord(recordType: self.recordType, recordID: recordID)
                        newRecord["roomName"] = roomName as CKRecordValue
                        newRecord["mapAsset"] = CKAsset(fileURL: fileURL)
                        newRecord["lastModified"] = lastModified as CKRecordValue
                        CloudKitService.shared.saveRecord(newRecord) { saveResult in
                            switch saveResult {
                            case .success:
                                print("Uploaded \(roomName) to CloudKit in custom zone.")
                            case .failure(let error):
                                print("Error saving to CloudKit: \(error.localizedDescription)")
                            }
                            completion?()
                        }
                    }
                case .failure(let error):
                    print("Error querying CloudKit: \(error.localizedDescription)")
                    completion?()
                }
            }
        }
    }

    
    // MARK: - Load World Map
    func loadWorldMap(roomName: String, completion: @escaping (Data?, ARWorldMap?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: ["mapAsset"]) { [weak self] result in
            guard let _ = self else { return }
            switch result {
            case .success(let records):
                guard let record = records.first,
                      let asset = record["mapAsset"] as? CKAsset,
                      let assetFileURL = asset.fileURL else {
                    print("No valid record or asset for \(roomName).")
                    completion(nil, nil)
                    return
                }
                do {
                    let data = try Data(contentsOf: assetFileURL)
                    if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                        print("Local archive hash: \(sha256Hash(of: data))")
                        completion(data, container.map)
                    } else {
                        print("Failed to unarchive ARWorldMapContainer from CloudKit.")
                        completion(nil, nil)
                    }
                } catch {
                    print("Error loading CloudKit asset: \(error.localizedDescription)")
                    completion(nil, nil)
                }
            case .failure(let error):
                print("Error querying CloudKit: \(error.localizedDescription)")
                completion(nil, nil)
            }
        }
    }
    
    // MARK: - Delete World
    func deleteWorld(roomName: String, completion: @escaping (Error?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: nil) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let records):
                if !records.isEmpty {
                    let recordIDs = records.map { $0.recordID }
                    CloudKitService.shared.deleteRecords(with: recordIDs) { deleteResult in
                        switch deleteResult {
                        case .success:
                            print("World \(roomName) deleted from custom zone.")
                            DispatchQueue.main.async { completion(nil) }
                        case .failure(let error):
                            print("Error deleting records from custom zone: \(error.localizedDescription)")
                            DispatchQueue.main.async { completion(error) }
                        }
                    }
                } else {
                    print("No records found in custom zone for \(roomName), trying default zone.")
                    CloudKitService.shared.performQuery(recordType: self.recordType,
                                                        predicate: predicate,
                                                        zoneID: nil,
                                                        desiredKeys: nil) { [weak self] defaultResult in
                        guard let self = self else { return }
                        switch defaultResult {
                        case .success(let defaultRecords):
                            if defaultRecords.isEmpty {
                                print("No records found for \(roomName) in default zone.")
                                DispatchQueue.main.async { completion(nil) }
                            } else {
                                let recordIDs = defaultRecords.map { $0.recordID }
                                CloudKitService.shared.deleteRecords(with: recordIDs) { deleteResult in
                                    switch deleteResult {
                                    case .success:
                                        print("World \(roomName) deleted from default zone.")
                                        DispatchQueue.main.async { completion(nil) }
                                    case .failure(let error):
                                        print("Error deleting records from default zone: \(error.localizedDescription)")
                                        DispatchQueue.main.async { completion(error) }
                                    }
                                }
                            }
                        case .failure(let error):
                            print("Error querying default zone: \(error.localizedDescription)")
                            DispatchQueue.main.async { completion(error) }
                        }
                    }
                }
            case .failure(let error):
                print("Error performing query: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    
    
    // MARK: - Fetch Last Modified
    func fetchLastModified(for roomName: String, completion: @escaping (Date?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: ["lastModified"]) { result in
            switch result {
            case .success(let records):
                if let record = records.first, let lastModified = record["lastModified"] as? Date {
                    completion(lastModified)
                } else {
                    completion(nil)
                }
            case .failure(let error):
                print("❌ fetchLastModified error: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
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
        share.publicPermission = .readOnly
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
    
    func createCustomZoneIfNeeded() {
        let zone = CKRecordZone(zoneID: customZoneID)
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        op.modifyRecordZonesResultBlock = {  result in
            switch result {
            case .success:
                print("Custom zone created or already exists.")
            case .failure(let error):
                print("Error creating custom zone: \(error.localizedDescription)")
            }
        }
        privateDB.add(op)
    }
    
    
}
