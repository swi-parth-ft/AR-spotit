//
//  SpotlightManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-11.
//
import ARKit
import CloudKit
import CoreSpotlight
import MobileCoreServices
import SwiftUI


//MARK: Spotlight Operations
extension WorldManager {
    
    func indexWorlds() {
        let searchableItems = savedWorlds.map { createSearchableItem(for: $0) }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Successfully indexed \(searchableItems.count) worlds")
            }
        }
    }
    
    private func createSearchableItem(for world: WorldModel) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributeSet.title = world.name
        attributeSet.contentDescription = "Explore the \(world.name) in it's here."
        // Optionally, add keywords, thumbnail, etc.
        // Example: attributeSet.keywords = ["AR", "World", "Spotit"]
        if let snapshotImage = getSnapshotImage(for: world) {
            attributeSet.thumbnailData = snapshotImage.pngData()
        }
        
        let uniqueIdentifier = "com.parthant.AR-spotit.\(world.name)"
        let domainIdentifier = "com.parthant.AR-spotit"
        
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    
    private func getSnapshotImage(for world: WorldModel) -> UIImage? {
        let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(world.name)_snapshot.png")
        if FileManager.default.fileExists(atPath: snapshotPath.path),
           let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
            return uiImage
        }
        return nil
    }
    
    
    func indexItems(anchors: [(anchorName: String, worldName: String)]) {
        let searchableItems = anchors.map { createSearchableAnchor(anchorName: $0.anchorName, worldName: $0.worldName) }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Successfully indexed \(searchableItems.count) items")
            }
        }
    }
    
    private func createSearchableAnchor(anchorName: String, worldName: String) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributeSet.title = anchorName
        attributeSet.contentDescription = "Search for \(anchorName) in world \(worldName)"
        
        // Incorporate both worldName and anchorName in the unique identifier.
        let uniqueIdentifier = "item.com.parthant.AR-spotit.\(worldName).\(anchorName)"
        let domainIdentifier = "com.parthant.AR-spotit"
        
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
}
