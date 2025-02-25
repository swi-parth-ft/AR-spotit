//
//  ARAnchorCURD.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-18.
//

import SwiftUI
import ARKit
import CoreHaptics
import Drops
import AVFoundation
import CloudKit

extension ARViewContainer.Coordinator {
    //MARK: CURD on anchors
    func deleteAnchor(anchorName: String, recId: String) {
      
        guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
            print("Anchor with name \(anchorName) not found.")
            return
        }
        
        if recId == "" {
            parent.sceneView.session.remove(anchor: anchor)
          
            return
        }
        
        if let record = publicRecord {
            let predicate = NSPredicate(format: "worldRecordName == %@ AND name == %@", record.recordID.recordName, anchorName)
            
            // Create a query on the "Anchor" record type.
            let query = CKQuery(recordType: "Anchor", predicate: predicate)
            
            // Use the public database if your anchors are saved there.
            let publicDB = CKContainer.default().publicCloudDatabase
            
            publicDB.perform(query, inZoneWith: nil) { records, error in
                if let error = error {
                    print("Error querying anchor: \(error.localizedDescription)")
                    return
                    }
                    
                
                
                guard let records = records, let anchorRecord = records.first else {
                    print("No matching anchor record found for \(anchorName) in world \(record.recordID.recordName).")
                    return
                }
                
                // Delete the fetched anchor record.
                publicDB.delete(withRecordID: anchorRecord.recordID) { deletedRecordID, deleteError in
                    if let deleteError = deleteError {
                        print("Error deleting anchor: \(deleteError.localizedDescription)")
                    } else {
                        print("Anchor \(anchorName) deleted successfully from CloudKit.")
                    }
                }
            }
        } else {
            CKContainer.default().publicCloudDatabase.fetch(withRecordID: CKRecord.ID(recordName: recId)) { record, error in
                if let error = error {
                    print("Error fetching world record from public DB: \(error.localizedDescription)")
                    return
                }
                guard record != nil else {
                    
                    print("No world record found for recordID: \(recId)")
                    return
                }
                
                if let r = record {
                    self.publicRecord = r
                    print("new record created")
                    
                    let predicate = NSPredicate(format: "worldRecordName == %@ AND name == %@", r.recordID.recordName, anchorName)
                    
                    // Create a query on the "Anchor" record type.
                    let query = CKQuery(recordType: "Anchor", predicate: predicate)
                    
                    // Use the public database if your anchors are saved there.
                    let publicDB = CKContainer.default().publicCloudDatabase
                    
                    publicDB.perform(query, inZoneWith: nil) { records, error in
                        if let error = error {
                            print("Error querying anchor: \(error.localizedDescription)")
                            return
                        }
                        
                        
                        
                        guard let records = records, let anchorRecord = records.first else {
                            print("No matching anchor record found for \(anchorName) in world \(r.recordID.recordName).")
                            return
                        }
                        
                        // Delete the fetched anchor record.
                        publicDB.delete(withRecordID: anchorRecord.recordID) { deletedRecordID, deleteError in
                            if let deleteError = deleteError {
                                print("Error deleting anchor: \(deleteError.localizedDescription)")
                            } else {
                                print("Anchor \(anchorName) deleted successfully from CloudKit.")
                            }
                        }
                    }
                }
                
            }
        }
        
        parent.sceneView.session.remove(anchor: anchor)
   
        
    }
    
    func renameAnchor(oldName: String, newName: String, recId: String) {
        guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == oldName }) else {
            print("Anchor with name \(oldName) not found.")
            return
        }
        
        // Create a new anchor with the updated name
        let newAnchor = ARAnchor(name: newName, transform: anchor.transform)
        deleteAnchor(anchorName: oldName, recId: recId)
        addNewAnchor(anchor: newAnchor, recId: recId)
//            parent.sceneView.session.remove(anchor: anchor)
   //     parent.sceneView.session.add(anchor: newAnchor)
        let drop = Drop.init(title: "Renamed from \(oldName) to \(newName)")
        Drops.show(drop)
        print("Anchor renamed from \(oldName) to \(newName).")
        if parent.findAnchor == "" {
            HapticManager.shared.notification(type: .success)
        }
    }
    
    func addNewAnchor(anchor: ARAnchor, recId: String) {
        
        
        parent.sceneView.session.add(anchor: anchor)
        
        if AppState.shared.isiCloudShare || parent.isCollab {
            if (WorldManager.shared.currentWorldRecord != nil && WorldManager.shared.isCollaborative) {
                iCloudManager.shared.saveAnchor(anchor, for: WorldManager.shared.currentRoomName, worldRecord: WorldManager.shared.currentWorldRecord!) { error in
                    if let error = error {
                        print("Error saving new anchor: \(error.localizedDescription)")
                    } else {
                        print("Anchor \(anchor.name ?? "") saved for collaboration.")
                    }
                }
            } else {
                if publicRecord == nil {
                    
                    
                    CKContainer.default().publicCloudDatabase.fetch(withRecordID: CKRecord.ID(recordName: parent.recordName)) { record, error in
                        if let error = error {
                            print("Error fetching world record from public DB: \(error.localizedDescription)")
                            return
                        }
                        guard let pRecord = record else {
                            
                            print("No world record found for recordID: \(self.parent.recordName)")
                            return
                        }
                        
                        self.publicRecord = record
                        print("new record created")
                        iCloudManager.shared.saveAnchor(anchor, for: self.parent.roomName, worldRecord: pRecord) { error in
                            if let error = error {
                                print("Error saving new anchor: \(error.localizedDescription)")
                            } else {
                                print("Anchor \(anchor.name ?? "") saved for collaboration.")
                            }
                        }
                        
                    }
                } else {
                    if let record = publicRecord {
                        iCloudManager.shared.saveAnchor(anchor, for: self.parent.roomName, worldRecord: record) { error in
                            if let error = error {
                                print("Error saving new anchor: \(error.localizedDescription)")
                            } else {
                                print("Anchor \(anchor.name ?? "") saved for collaboration.")
                            }
                        }
                    }
                }
            }
        }
        if AppState.shared.publicRecordName != "" {
            if publicRecord == nil {
                let recordName = AppState.shared.publicRecordName
                CKContainer.default().publicCloudDatabase.fetch(
                    withRecordID: CKRecord.ID(recordName: recordName)
                ) { record, error in
                    if let pRecord = record {
                        
                        self.publicRecord = pRecord
                        // 3) Save anchors to the public record
                        iCloudManager.shared.saveAnchor(anchor,
                                                        for: self.parent.roomName,
                                                        worldRecord: pRecord) { error in
                            if let error = error {
                                print("Error saving anchor: \(error.localizedDescription)")
                            } else {
                                print("Anchor saved to public DB!")
                            }
                        }
                        
                        
                    }
                }
            } else {
                if let record = publicRecord {
                    iCloudManager.shared.saveAnchor(anchor,
                                                    for: self.parent.roomName,
                                                    worldRecord: record) { error in
                        if let error = error {
                            print("Error saving anchor: \(error.localizedDescription)")
                        } else {
                            print("Anchor saved to public DB!")
                        }
                    }
                }
               
            }
            
        }

    }
    
    func prepareToMoveAnchor(anchorName: String, recId: String) {
        guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
            print("Anchor with name \(anchorName) not found.")
            return
        }
        
        // Store the anchor temporarily
        parent.tempAnchor = anchor
        deleteAnchor(anchorName: anchorName, recId: recId)
//            parent.sceneView.session.remove(anchor: anchor)
        print("Anchor '\(anchorName)' prepared for moving.")
        let drop = Drop.init(title: "Tap new location to move \(anchorName)")
        Drops.show(drop)
        if parent.findAnchor == "" {
            HapticManager.shared.notification(type: .warning)
        }
    }
    
    //MARK: Unique anchor names
    func getUniqueAnchorName(baseName: String, existingNames: [String]) -> String {
        // If the base name is not already used, return it immediately.
        if !existingNames.contains(baseName) {
            return baseName
        }
        
        // Try to detect an emoji at the end of the base name.
        // (This assumes your emoji is the very last character.)
        let trimmedBaseName: String
        let trailingEmoji: String?
        if let lastChar = baseName.last, lastChar.isEmoji {
            trailingEmoji = String(lastChar)
            // Remove the emoji and any trailing whitespace.
            trimmedBaseName = String(baseName.dropLast()).trimmingCharacters(in: .whitespaces)
        } else {
            trailingEmoji = nil
            trimmedBaseName = baseName
        }
        
        // Append a counter until we find a name that isn’t used.
        var counter = 1
        var newName: String
        repeat {
            if let emoji = trailingEmoji {
                newName = "\(trimmedBaseName)\(counter) \(emoji)"
            } else {
                newName = "\(trimmedBaseName)\(counter)"
            }
            counter += 1
        } while existingNames.contains(newName)
        
        return newName
    }
    
    //MARK: Add new Anchors from public database
    func addNewAnchorsFromPublicDatabase() {
        var uniqueRecords = 0
        if let world = worldManager.savedWorlds.first(where: { $0.name == parent.roomName }), world.isCollaborative,
           let recordName = world.publicRecordName {
          
            iCloudManager.shared.fetchNewAnchors(for: recordName) { records in
                DispatchQueue.main.async {
                    for record in records {

                        if let transformData = record["transform"] as? Data {
                            let transform = transformData.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
                            
                            
                            let anchorName = record["name"] as? String
                            let newAnchor = ARAnchor(name: anchorName ?? "noname", transform: transform)
                            
                            // Avoid adding duplicates by checking the transform.
                            if !self.parent.sceneView.session.currentFrame!.anchors.contains(where: { $0.name == newAnchor.name }) {
                                self.parent.sceneView.session.add(anchor: newAnchor)
                                self.worldManager.anchorRecordIDs[record["name"] as? String ?? UUID().uuidString] = record.recordID.recordName

                                print("✅ Added new anchor \(newAnchor.name ?? "") from CloudKit.")
                                
                                uniqueRecords += 1
                                
                                
                            }
                        }
                    }
                    
                    let drop = Drop.init(title: "\(uniqueRecords) new items added.")
                    Drops.show(drop)
                }
            }
        }
    }
    
}
