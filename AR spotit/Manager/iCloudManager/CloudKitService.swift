//
//  CloudKitService.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-11.
//

import CloudKit

class CloudKitService {
    static let shared = CloudKitService()
    private let privateDB = CKContainer.default().privateCloudDatabase
    
    // Generic query method using the new fetchRecordsResultBlock API
    func performQuery(recordType: String,
                      predicate: NSPredicate,
                      zoneID: CKRecordZone.ID? = nil,
                      desiredKeys: [String]? = nil,
                      completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        privateDB.fetch(withQuery: query,
                        inZoneWith: zoneID,
                        desiredKeys: desiredKeys,
                        resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                    if case .success(let record) = recordResult { return record }
                    return nil
                }
                completion(.success(records))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Save record helper
    func saveRecord(_ record: CKRecord, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        privateDB.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                completion(.success(savedRecord))
            }
        }
    }
    
    // Delete records helper
    func deleteRecords(with recordIDs: [CKRecord.ID], completion: @escaping (Result<[CKRecord.ID], Error>) -> Void) {
        let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        deleteOp.modifyRecordsCompletionBlock = { _, deletedRecordIDs, error in
            if let error = error {
                completion(.failure(error))
            } else if let deletedRecordIDs = deletedRecordIDs {
                completion(.success(deletedRecordIDs))
            }
        }
        privateDB.add(deleteOp)
    }
}
