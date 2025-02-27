//
//  DepricatedFuns.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-17.
//

import Foundation


//MARK: Deprecated iCloud Functions
#if false


//MARK: WorldManager funcs
private func loadWorldMapDataFromCloudKitOnly(roomName: String, completion: @escaping (ARWorldMap?) -> Void) {
    let privateDB = CKContainer.default().privateCloudDatabase
    let predicate = NSPredicate(format: "roomName == %@", roomName)
    let query = CKQuery(recordType: recordType, predicate: predicate)
    
    privateDB.perform(query, inZoneWith: nil) { records, error in
        if let error = error as? CKError {
            print("CloudKit query error: \(error.localizedDescription)")
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
            if let unarchivedMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                self.saveLocallyAfterCloudDownload(roomName: roomName, data: data, lastModified: Date())
                completion(unarchivedMap)
            } else {
                print("Failed to unarchive ARWorldMap from CloudKit data.")
                completion(nil)
            }
        } catch {
            print("Error loading CloudKit asset: \(error.localizedDescription)")
            completion(nil)
        }
    }
}

func uploadARWorldMapToCloudKit(roomName: String, data: Data, lastModified: Date, completion: (() -> Void)? = nil) {
    DispatchQueue.global(qos: .background).async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(roomName)_tempWorldMap")
        do {
            try data.write(to: tempURL)
            let record = CKRecord(recordType: self.recordType)
            record["roomName"] = roomName as CKRecordValue
            record["mapAsset"] = CKAsset(fileURL: tempURL)
            record["lastModified"] = lastModified as CKRecordValue
            
            let privateDB = CKContainer.default().privateCloudDatabase
            privateDB.save(record) { savedRecord, error in
                try? FileManager.default.removeItem(at: tempURL)
                if let error = error {
                    print("Error uploading to CloudKit: \(error.localizedDescription)")
                } else {
                    print("Uploaded \(roomName) to CloudKit.")
                }
                completion?()
            }
        } catch {
            print("Error writing temp file: \(error.localizedDescription)")
            completion?()
        }
    }
}

func deleteAnchor(anchorName: String, node: SCNNode) {
    guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
        print("Anchor not found in session.")
        return
    }
    
    // Remove the anchor
    parent.sceneView.session.remove(anchor: anchor)
    node.removeFromParentNode()
    print("Anchor '\(anchorName)' deleted.")
    
    // Optionally, update WorldManager state
    DispatchQueue.main.async {
        self.worldManager.deletedAnchors.append(anchor)
    }
}

//MARK: ARViewContainer funcs


func createArrowNode() -> SCNNode {
    // Shaft
    let cylinder = SCNCylinder(radius: 0.02, height: 0.1)
    cylinder.firstMaterial?.diffuse.contents = UIColor.red
    let shaftNode = SCNNode(geometry: cylinder)
    shaftNode.position = SCNVector3(0, 0.05, 0)
    
    // Head
    let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.04, height: 0.08)
    cone.firstMaterial?.diffuse.contents = UIColor.red
    let headNode = SCNNode(geometry: cone)
    headNode.position = SCNVector3(0, 0.14, 0)
    
    // Combine
    let arrowNode = SCNNode()
    arrowNode.addChildNode(shaftNode)
    arrowNode.addChildNode(headNode)
    
    // Rotate so arrow is along -Z by default
    arrowNode.eulerAngles.x = -.pi / 2
    
    return arrowNode
}

func placeArrowInFrontOfCamera(targetPosition: SIMD3<Float>) {
    guard let currentFrame = parent.sceneView.session.currentFrame else {
        print("No current AR frame available.")
        return
    }
    // Camera transform
    let camTransform = currentFrame.camera.transform
    let camPos = SIMD3<Float>(camTransform.columns.3.x,
                              camTransform.columns.3.y,
                              camTransform.columns.3.z)
    // Forward is -Z
    let forwardDir = normalize(SIMD3<Float>(-camTransform.columns.2.x,
                                            -camTransform.columns.2.y,
                                            -camTransform.columns.2.z))
    // Place arrow ~1m in front
    let arrowPos = camPos + (forwardDir * 1.0)
    
    let arrowNode = createArrowNode()
    arrowNode.position = SCNVector3(arrowPos.x, arrowPos.y, arrowPos.z)
    parent.sceneView.scene.rootNode.addChildNode(arrowNode)
    currentArrowNode = arrowNode
    
    // Point toward desired zone
    pointArrowToward(arrowNode, targetPosition: targetPosition)
}

func ensureArrowInView(_ arrowNode: SCNNode, targetPosition: SIMD3<Float>) {
    guard let currentFrame = parent.sceneView.session.currentFrame else { return }
    
    let cameraTransform = currentFrame.camera.transform
    let forwardDirection = normalize(SIMD3<Float>(-cameraTransform.columns.2.x,
                                                  -cameraTransform.columns.2.y,
                                                  -cameraTransform.columns.2.z))
    let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                      cameraTransform.columns.3.y,
                                      cameraTransform.columns.3.z)
    let adjustedPosition = cameraPosition + (forwardDirection * 1.0)
    arrowNode.position = SCNVector3(adjustedPosition.x, adjustedPosition.y, adjustedPosition.z)
    
    pointArrowToward(arrowNode, targetPosition: targetPosition)
}

func pointArrowToward(_ arrowNode: SCNNode, targetPosition: SIMD3<Float>) {
    let arrowPosition = SIMD3<Float>(arrowNode.position.x, arrowNode.position.y, arrowNode.position.z)
    let direction = normalize(targetPosition - arrowPosition)
    
    // Build a transform that looks down negative Z = direction
    var transform = matrix_identity_float4x4
    transform.columns.2 = SIMD4<Float>(-direction.x, -direction.y, -direction.z, 0)
    // Keep Y as global up or a cross-based approach, depending on your needs:
    transform.columns.1 = SIMD4<Float>(0, 1, 0, 0)
    // Recompute X as cross(Y, Z)
    transform.columns.0 = SIMD4<Float>(
        direction.y * transform.columns.1.z - direction.z * transform.columns.1.y,
        direction.z * transform.columns.1.x - direction.x * transform.columns.1.z,
        direction.x * transform.columns.1.y - direction.y * transform.columns.1.x,
        0
    )
    transform.columns.3 = SIMD4<Float>(arrowPosition, 1)
    
    arrowNode.transform = SCNMatrix4(transform)
}

func removeArrow() {
    currentArrowNode?.removeFromParentNode()
    currentArrowNode = nil
    print("Arrow removed.")
}


//MARK: App Intent Funcs

struct WorldNameOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        // Wait for the saved worlds to load
        try await withCheckedThrowingContinuation { continuation in
            WorldManager.shared.loadSavedWorlds {
                let worlds = WorldManager.shared.savedWorlds.map { $0.name }
                print(worlds) // Ensure worlds are printed correctly
                continuation.resume(returning: worlds)
            }
        }
    }
}
struct AnchorNameOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            WorldManager.shared.loadSavedWorlds {
                Task {
                    var items: [String] = []

                    await withTaskGroup(of: [String].self) { group in
                        for world in WorldManager.shared.savedWorlds {
                            group.addTask {
                                await withCheckedContinuation { innerContinuation in
                                    WorldManager.shared.getAnchorNames(for: world.name) { fetchedAnchors in
                                        let filteredAnchors = fetchedAnchors.filter { $0.lowercased() != "guide" }
                                        innerContinuation.resume(returning: filteredAnchors)                                    }
                                }
                            }
                        }

                        // Collect results from all tasks
                        for await fetchedAnchors in group {
                            items.append(contentsOf: fetchedAnchors)
                        }
                    }

                    continuation.resume(returning: items)
                }
            }
        }
    }
}


// MARK: - Delete All Records
func deleteAllRecords(completion: @escaping (Error?) -> Void) {
    let recordTypes = ["ARWorldMapRecord", "WorldListRecord"]
    let dispatchGroup = DispatchGroup()
    var finalError: Error?
    for recordType in recordTypes {
        dispatchGroup.enter()
        let zoneID: CKRecordZone.ID? = (recordType == "ARWorldMapRecord") ? customZoneID : nil
        CloudKitService.shared.performQuery(recordType: recordType,
                                            predicate: NSPredicate(value: true),
                                            zoneID: zoneID,
                                            desiredKeys: nil) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let records):
                let recordIDs = records.map { $0.recordID }
                if recordIDs.isEmpty {
                    print("No records found for \(recordType).")
                    dispatchGroup.leave()
                    return
                }
                CloudKitService.shared.deleteRecords(with: recordIDs) { deleteResult in
                    switch deleteResult {
                    case .success:
                        print("Successfully deleted all records of type \(recordType).")
                    case .failure(let error):
                        print("Error deleting records for \(recordType): \(error.localizedDescription)")
                        finalError = error
                    }
                    dispatchGroup.leave()
                }
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


private func handleIncomingShareURL(_ url: URL) {
    print("Incoming CloudKit share URL: \(url.absoluteString)")
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
            if let sharedRecord = share.value(forKey: "rootRecord") as? CKRecord {
                print("Fetched sharedRecord from share: \(sharedRecord.recordID)")
                WorldManager.shared.processIncomingSharedRecord(sharedRecord, withShare: share)
            } else {
                let rootRecordID = metadata.rootRecordID
                print("No rootRecord in share; fetching using rootRecordID: \(rootRecordID)")
                CKContainer.default().sharedCloudDatabase.fetch(withRecordID: rootRecordID) { fetchedRecord, fetchError in
                    if let fetchError = fetchError {
                        print("Error fetching root record: \(fetchError.localizedDescription)")
                    } else if let fetchedRecord = fetchedRecord {
                        print("Fetched root record via fetch: \(fetchedRecord.recordID)")
                        WorldManager.shared.processIncomingSharedRecord(fetchedRecord, withShare: share)
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


#endif
