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
        // Create list of unique identifiers for each world
        let identifiers = savedWorlds.map { "com.parthant.AR-spotit.\($0.name)" }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { [weak self] error in
            if let error = error {
                print("Error deleting worlds: \(error.localizedDescription)")
            } else {
                print("Successfully deleted existing worlds")
            }
            guard let self = self else { return }
            let searchableItems = self.savedWorlds.map { self.createSearchableItem(for: $0) }
            CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("Successfully indexed \(searchableItems.count) worlds")
                }
            }
        }
    }
    
    /// Creates a searchable item for a given world.
    private func createSearchableItem(for world: WorldModel) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributeSet.title = world.name
        attributeSet.contentDescription = "Explore the \(world.name) in it's here."

        if let snapshotImage = getSnapshotImage(for: world) {
            attributeSet.thumbnailData = snapshotImage.pngData()
        }
        
        let uniqueIdentifier = "com.parthant.AR-spotit.\(world.name)"
        let domainIdentifier = "com.parthant.AR-spotit"
        
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier,
                                domainIdentifier: domainIdentifier,
                                attributeSet: attributeSet)
    }
    
    /// Retrieves the snapshot image for a given world if available.
    private func getSnapshotImage(for world: WorldModel) -> UIImage? {
        let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(world.name)_snapshot.png")
        if FileManager.default.fileExists(atPath: snapshotPath.path),
           let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
            return uiImage
        }
        return nil
    }
    
    /// Indexes the provided anchors/items.
    /// It first deletes any previously indexed items with matching identifiers to avoid duplication.
    func indexItems(anchors: [(anchorName: String, worldName: String)]) {
        // Create list of unique identifiers for each anchor item.
        let identifiers = anchors.map { "item.com.parthant.AR-spotit.\($0.worldName).\($0.anchorName)" }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { [weak self] error in
            if let error = error {
                print("Error deleting items: \(error.localizedDescription)")
            } else {
                print("Successfully deleted existing items")
            }
            guard let self = self else { return }
            let searchableItems = anchors.map {
                self.createSearchableAnchor(anchorName: $0.anchorName, worldName: $0.worldName)
            }
            CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("Successfully indexed \(searchableItems.count) items")
                }
            }
        }
    }
    
    /// Creates a searchable anchor item for the given anchor and world.
    private func createSearchableAnchor(anchorName: String, worldName: String) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributeSet.title = anchorName
        attributeSet.contentDescription = "Search for \(anchorName) in world \(worldName)"
        
        // Incorporate both worldName and anchorName in the unique identifier.
        let uniqueIdentifier = "item.com.parthant.AR-spotit.\(worldName).\(anchorName)"
        let domainIdentifier = "com.parthant.AR-spotit"
        
        return CSSearchableItem(uniqueIdentifier: uniqueIdentifier,
                                domainIdentifier: domainIdentifier,
                                attributeSet: attributeSet)
    }
}
