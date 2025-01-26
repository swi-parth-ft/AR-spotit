//
//  iCloudManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-16.
//

import Foundation
import CloudKit
import ARKit

typealias FetchResult = Result<
    (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
     queryCursor: CKQueryOperation.Cursor?),
    Error
>

class iCloudManager {
    private let recordType = "ARWorldMapRecord"
    private let privateDB = CKContainer.default().privateCloudDatabase
    weak var worldManager: WorldManager? // Use a weak reference to avoid circular dependency
    
    init(worldManager: WorldManager?) {
        self.worldManager = worldManager
    }
    
    // Upload ARWorldMap to iCloud
    func uploadWorldMap(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(roomName)_tempWorldMap")
            
            // Write data to tempURL
            do {
                try data.write(to: tempURL)
            } catch {
                print("Error writing to tempURL: \(error.localizedDescription)")
                completion?()
                return
            }
            
            let predicate = NSPredicate(format: "roomName == %@", roomName)
            let query = CKQuery(recordType: self.recordType, predicate: predicate)
            
            self.privateDB.perform(query, inZoneWith: nil) { records, error in
                if let error = error {
                    print("Error querying CloudKit: \(error.localizedDescription)")
                    try? FileManager.default.removeItem(at: tempURL) // Cleanup temp file
                    completion?()
                    return
                }
                
                if let record = records?.first { // Record exists, update it
                    record["mapAsset"] = CKAsset(fileURL: tempURL)
                    record["lastModified"] = lastModified as CKRecordValue
                    
                    self.privateDB.save(record) { _, error in
                        try? FileManager.default.removeItem(at: tempURL)
                        if let error = error {
                            print("Error updating record in CloudKit: \(error.localizedDescription)")
                        } else {
                            print("Updated \(roomName) in CloudKit.")
                        }
                        completion?()
                    }
                } else { // Record doesn't exist, create a new one
                    let record = CKRecord(recordType: self.recordType)
                    record["roomName"] = roomName as CKRecordValue
                    record["mapAsset"] = CKAsset(fileURL: tempURL)
                    record["lastModified"] = lastModified as CKRecordValue
                    
                    self.privateDB.save(record) { _, error in
                        try? FileManager.default.removeItem(at: tempURL)
                        if let error = error {
                            print("Error saving to CloudKit: \(error.localizedDescription)")
                        } else {
                            print("Uploaded \(roomName) to CloudKit.")
                        }
                        completion?()
                    }
                }
            }
        }
    }
    
    // Fetch World Names from iCloud
    func fetchWorldNames(completion: @escaping ([WorldModel]) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["roomName", "lastModified"], resultsLimit: CKQueryOperation.maximumResults) { result in
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
                completion([])
            }
        }
    }
    
    // Load World Map Data from iCloud
    func loadWorldMap(roomName: String, completion: @escaping (ARWorldMap?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error querying CloudKit: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let record = records?.first,
                  let asset = record["mapAsset"] as? CKAsset,
                  let assetFileURL = asset.fileURL else {
                print("No valid record or asset for \(roomName).")
                completion(nil)
                return
            }
            do {
                let data = try Data(contentsOf: assetFileURL)
                if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                    let worldMap = container.map
                    completion(worldMap)
                } else {
                    print("Failed to unarchive ARWorldMapContainer from CloudKit.")
                    completion(nil)
                }
            } catch {
                print("Error loading CloudKit asset: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // Delete World from iCloud
    func deleteWorld(roomName: String, completion: @escaping (Error?) -> Void) {
        let predicate = NSPredicate(format: "roomName == %@", roomName)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error performing query: \(error.localizedDescription)")
                completion(error)
                return
            }
            guard let records = records, !records.isEmpty else {
                print("No records found for \(roomName).")
                completion(nil)
                return
            }
            let recordIDs = records.map { $0.recordID }
            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            deleteOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("World \(roomName) deleted from CloudKit.")
                    completion(nil)
                case .failure(let error):
                    print("Error deleting records: \(error.localizedDescription)")
                    completion(error)
                }
            }
            self.privateDB.add(deleteOperation)
        }
    }
    
    
    //MARK: Golden function to delete everything from iCloud.
    func deleteAllRecords(completion: @escaping (Error?) -> Void) {
        let privateDB = CKContainer.default().privateCloudDatabase
        let recordTypes = ["ARWorldMapRecord", "WorldListRecord"] // Add all your record types here
        
        let dispatchGroup = DispatchGroup()
        var finalError: Error?
        
        for recordType in recordTypes {
            dispatchGroup.enter()
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            
            privateDB.fetch(
                withQuery: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
                
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
                    
                    privateDB.add(deleteOperation)
                    
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
    
    
}
