//
//  RenameNImport.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-11.
//

import SwiftUI
import Drops


extension WorldManager {
    func renameWorld(currentName: String, newName: String, publicName: String, completion: (() -> Void)? = nil) {
        // Ensure new name is not empty
        guard !newName.isEmpty else {
            print("❌ New name cannot be empty.")
            completion?()
            return
        }
        
        // Check if the world with currentName exists
        guard let world = savedWorlds.first(where: { $0.name == currentName }) else {
            print("❌ No world found with name \(currentName).")
            completion?()
            return
        }
        
        let oldFilePath = world.filePath
        
        // Try to load world map data from local storage first
        do {
            let data = try Data(contentsOf: oldFilePath)
            renameAndSaveWorld(data: data, currentName: currentName, newName: newName, publicName: publicName, completion: completion)
            completion?()
            return
        } catch {
            print("⚠️ Local file not found for \(currentName). Trying to fetch from iCloud...")
            

        }
        
        // 3) If not local, load from iCloud
        iCloudManager.loadWorldMap(roomName: currentName) { [weak self] data, arMap in
            guard let self = self else { return }
            
            // If no data found, fail
            guard let data = data else {
                print("❌ Failed to fetch \(currentName) from iCloud.")
                completion?()
                return
            }
            
            // Now we have the actual container data from CloudKit
            self.renameAndSaveWorld(data: data, currentName: currentName, newName: newName, publicName: publicName, completion: completion)
        }
    }
    
    private func renameAndSaveWorld(data: Data, currentName: String, newName: String, publicName: String, completion: (() -> Void)?) {
        print("renaming with public name: \(publicName)")
        saveImportedWorld(data: data, worldName: newName)
        // 2) Rename the snapshot file, if it exists
           let oldSnapshotURL = WorldModel.appSupportDirectory
               .appendingPathComponent("\(currentName)_snapshot.png")
           let newSnapshotURL = WorldModel.appSupportDirectory
               .appendingPathComponent("\(newName)_snapshot.png")
           
           if FileManager.default.fileExists(atPath: oldSnapshotURL.path) {
               do {
                   try FileManager.default.moveItem(at: oldSnapshotURL, to: newSnapshotURL)
                   print("✅ Snapshot renamed from \(currentName) to \(newName).")
               } catch {
                   print("❌ Error renaming snapshot: \(error.localizedDescription)")
               }
           } else {
               print("No existing snapshot found for \(currentName).")
           }
  
        deleteWorld(roomName: currentName, publicName: publicName) {
            
         
            print("✅ Renamed \(currentName) to \(newName) successfully.")
          
                
            
            DispatchQueue.main.async {
                self.reload.toggle()
                AppState.shared.isWorldUpdated.toggle() // Notify WorldsView

                
            }
            
            HapticManager.shared.notification(type: .success)

            let drop = Drop.init(title: "Renamed \(currentName) to \(newName)")
            Drops.show(drop)
            
            completion?()
        }
    }
    
    func importWorldFromURL(_ url: URL) {
        DispatchQueue.main.async {
            self.importWorldURL = url
            self.tempWorldName = url.deletingPathExtension().lastPathComponent // Default name
            self.isImportingWorld = true
        }
        // Store the URL and show the sheet for naming
       
    }
    
    func saveImportedWorld(data: Data, worldName: String) {
        let timestamp = Date()
        
        // Check if the world already exists
        if let index = self.savedWorlds.firstIndex(where: { $0.name == worldName }) {
            self.savedWorlds[index].lastModified = timestamp
        } else {
            self.savedWorlds.append(WorldModel(name: worldName, lastModified: timestamp))
        }
        
        // Save to local file
        guard let newWorld = self.savedWorlds.first(where: { $0.name == worldName }) else {
            print("Failed to find the newly created world.")
            return
        }
        
        do {
            try data.write(to: newWorld.filePath)
            self.saveWorldList()
            print("✅ Imported world saved as \(worldName).")
        } catch {
            print("❌ Error saving imported world: \(error.localizedDescription)")
        }
        
        // 2) **Unarchive the container** to extract snapshotData, then write as PNG:
        do {
            if let container = try NSKeyedUnarchiver
                .unarchivedObject(ofClass: ARWorldMapContainer.self, from: data),
               let snapshotData = container.imageData {
                
                let snapshotURL = WorldModel.appSupportDirectory
                    .appendingPathComponent("\(worldName)_snapshot.png")
                try snapshotData.write(to: snapshotURL)
                print("✅ Restored snapshot for \(worldName) at: \(snapshotURL.path)")
            }
        } catch {
            print("❌ Could not restore snapshot for \(worldName): \(error)")
        }
        
        iCloudManager.uploadWorldMap(roomName: worldName, data: data, lastModified: timestamp) {
            print("Sync to CloudKit complete for \(worldName).")
        }
    }
}
