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

class iCloudManager {
    
    static let shared = iCloudManager(worldManager: nil)
    let recordType = "ARWorldMapRecord"
    let customZoneID = CKRecordZone.ID(zoneName: "ARWorldMapZone", ownerName: CKCurrentUserDefaultName)
    let privateDB = CKContainer.default().privateCloudDatabase
    weak var worldManager: WorldManager?
    
    init(worldManager: WorldManager?) {
        self.worldManager = worldManager
        createCustomZoneIfNeeded()
    }
    
    /// Returns a stable recordName for a given roomName. Generates a UUID if needed.
    func getOrCreateRecordName(for roomName: String) -> String? {
        guard let wm = self.worldManager else { return nil }
        guard let index = wm.savedWorlds.firstIndex(where: { $0.name == roomName }) else {
            print("No local world found for \(roomName)")
            return nil
        }
        
        if let recordID = wm.savedWorlds[index].cloudRecordID {
            return recordID
        } else {
            let newRecordID = UUID().uuidString
            DispatchQueue.main.async {
                wm.savedWorlds[index].cloudRecordID = newRecordID
                wm.saveWorldList()
            }
            return newRecordID
        }
    }
    
    // MARK: - Upload ARWorldMap
    func uploadWorldMap(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            
            // Write local file
            let fileURL = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Error writing to local file path: \(error.localizedDescription)")
                completion?()
                return
            }
            
            // Ensure we have a stable recordName
            guard let recordName = self.getOrCreateRecordName(for: roomName) else {
                completion?()
                return
            }
            let recordID = CKRecord.ID(recordName: recordName, zoneID: self.customZoneID)
            
            // Fetch existing or create new
            self.privateDB.fetch(withRecordID: recordID) { fetchedRecord, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    // Not found => create new
                    let newRecord = CKRecord(recordType: self.recordType, recordID: recordID)
                    newRecord["roomName"] = roomName as CKRecordValue
                    newRecord["mapAsset"] = CKAsset(fileURL: fileURL)
                    newRecord["lastModified"] = lastModified as CKRecordValue
                    
                    CloudKitService.shared.saveRecord(newRecord) { result in
                        switch result {
                        case .success:
                            print("Uploaded \(roomName) to CloudKit (new record).")
                        case .failure(let e):
                            print("Error creating record in CloudKit: \(e.localizedDescription)")
                        }
                        completion?()
                    }
                    
                } else if let existing = fetchedRecord {
                    // => Update
                    existing["mapAsset"] = CKAsset(fileURL: fileURL)
                    existing["lastModified"] = lastModified as CKRecordValue
                    existing["roomName"] = roomName as CKRecordValue
                    
                    CloudKitService.shared.saveRecord(existing) { result in
                        switch result {
                        case .success:
                            print("Updated \(roomName) in CloudKit.")
                        case .failure(let e):
                            print("Error updating record in CloudKit: \(e.localizedDescription)")
                        }
                        completion?()
                    }
                    
                } else if let error = error {
                    print("❌ fetch error in uploadWorldMap: \(error.localizedDescription)")
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Load World Map
    func loadWorldMap(roomName: String, completion: @escaping (Data?, ARWorldMap?) -> Void) {
        // (Still queries by name, which is okay if you prefer.)
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
                    if let container = try NSKeyedUnarchiver
                        .unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
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
    
    func deleteWorld(roomName: String, publicName: String, completion: @escaping (Error?) -> Void) {
         let group = DispatchGroup()
         var finalError: Error? = nil
         
         // 1) Delete from custom zone
         group.enter()
         let customZonePredicate = NSPredicate(format: "roomName == %@", roomName)
         CloudKitService.shared.performQuery(recordType: recordType,
                                             predicate: customZonePredicate,
                                             zoneID: self.customZoneID,
                                             desiredKeys: nil) { [weak self] result in
             guard self != nil else { return }
             switch result {
             case .success(let records):
                 if !records.isEmpty {
                     let recordIDs = records.map { $0.recordID }
                     CloudKitService.shared.deleteRecords(with: recordIDs) { deleteResult in
                         switch deleteResult {
                         case .success:
                             print("✅ Deleted \(records.count) record(s) for \(roomName) from custom zone.")
                         case .failure(let error):
                             print("❌ Error deleting records from custom zone: \(error.localizedDescription)")
                             finalError = error
                         }
                         group.leave()
                     }
                 } else {
                     print("ℹ️ No ARWorldMapRecord found in custom zone for \(roomName).")
                     group.leave()
                 }
             case .failure(let error):
                 print("❌ Error querying custom zone for \(roomName): \(error.localizedDescription)")
                 finalError = error
                 group.leave()
             }
         }
         
         // 2) Delete from public default zone
         group.enter()
        if publicName != "" {
            deletePublicRecordAndAnchorsIfNeeded(publicRecordName: publicName) {_ in
                group.leave()

            }
        } else {
            group.leave()

        }

         group.enter()
         deleteWorldMetadata(roomName: roomName) { error in
             if let error = error {
                 finalError = error
             }
             group.leave()
         }
         
         
         
         // Notify when all deletions finish
         group.notify(queue: .main) {
             completion(finalError)
         }
     }
    
     
     func deleteWorldMetadata(roomName: String, completion: @escaping (Error?) -> Void) {
         let privateDB = CKContainer.default().privateCloudDatabase
         let predicate = NSPredicate(format: "roomName == %@", roomName)
         let query = CKQuery(recordType: "WorldMetadata", predicate: predicate)
         let operation = CKQueryOperation(query: query)
         
         var recordsToDelete: [CKRecord.ID] = []
         operation.recordFetchedBlock = { record in
             recordsToDelete.append(record.recordID)
         }
         operation.queryCompletionBlock = { cursor, error in
             if let error = error {
                 print("❌ Error querying WorldMetadata for \(roomName): \(error.localizedDescription)")
                 completion(error)
                 return
             }
             if recordsToDelete.isEmpty {
                 print("ℹ️ No WorldMetadata found for \(roomName). Nothing to delete.")
                 completion(nil)
                 return
             }
             
             // Now delete the fetched metadata records
             let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsToDelete)
             deleteOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, delError in
                 if let delError = delError {
                     print("❌ Error deleting WorldMetadata: \(delError.localizedDescription)")
                     completion(delError)
                 } else {
                     print("✅ Deleted \(deletedRecordIDs?.count ?? 0) WorldMetadata record(s) for \(roomName).")
                     completion(nil)
                 }
             }
             privateDB.add(deleteOp)
         }
         privateDB.add(operation)
     }
    
  
    // MARK: - Fetch Last Modified
    func fetchLastModified(for roomName: String, completion: @escaping (Date?) -> Void) {
        // same query approach or use unique ID
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: predicate,
                                            zoneID: self.customZoneID,
                                            desiredKeys: ["lastModified"]) { result in
            switch result {
            case .success(let records):
                if let record = records.first,
                   let lastModified = record["lastModified"] as? Date {
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
    
    func createCustomZoneIfNeeded() {
        let zone = CKRecordZone(zoneID: customZoneID)
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone],
                                              recordZoneIDsToDelete: nil)
        op.modifyRecordZonesResultBlock = { result in
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
