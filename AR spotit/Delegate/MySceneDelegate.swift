import UIKit
import CloudKit

class MySceneDelegate: NSObject, UIWindowSceneDelegate {
    // Save a reference to the original scene delegate so we can forward non‑share events.
    var originalDelegate: UISceneDelegate?
    
    // This method is called when the user accepts a CloudKit share.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        print("MySceneDelegate received share metadata: \(cloudKitShareMetadata)")
        // Post a notification for share URLs.
        NotificationCenter.default.post(name: Notifications.incomingShareURL, object: cloudKitShareMetadata)
        
        // Forward the callback to the original delegate (if it implements it).
        (originalDelegate as? UIWindowSceneDelegate)?.windowScene?(windowScene, userDidAcceptCloudKitShareWith: cloudKitShareMetadata)
    }
    
    // This method intercepts openURL events for the scene.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        var fileURLContexts = Set<UIOpenURLContext>()
        
        for context in URLContexts {
            let url = context.url
            print("MySceneDelegate openURLContexts received: \(url.absoluteString)")
            
            // Handle CloudKit share URLs as before
            if url.absoluteString.contains("ckshare") {
                NotificationCenter.default.post(name: Notifications.incomingShareURL, object: url)
            }
            // Handle custom collaboration URLs, e.g. itshere://collab?recordID=Fev1_Record
            else if let scheme = url.scheme, scheme.lowercased() == "itshere",
                    let host = url.host, host.lowercased() == "collab" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let recordIDItem = components.queryItems?.first(where: { $0.name == "recordID" }),
                   let recordIDString = recordIDItem.value {
                    print("Collaboration URL detected with recordID: \(recordIDString)")
                    let recordID = CKRecord.ID(recordName: recordIDString)
                    
                    // Fetch the public world record using the recordID from the public DB.
                    CKContainer.default().publicCloudDatabase.fetch(withRecordID: recordID) { record, error in
                        if let error = error {
                            print("Error fetching world record from public DB: \(error.localizedDescription)")
                            return
                        }
                        guard let publicRecord = record else {
                            print("No world record found for recordID: \(recordIDString)")
                            return
                        }
                        DispatchQueue.main.async {
                            // Extract room name from the public record
                            let roomName = publicRecord["roomName"] as? String ?? "Untitled"
                            
                            // Present an alert asking the user whether to open now or save locally.
                            let alert = UIAlertController(
                                title: "\(roomName) Received",
                                message: "Would you like to open now or save locally?",
                                preferredStyle: .alert
                            )
                            
                            let openAction = UIAlertAction(title: "Open Now", style: .default) { _ in
                                do {
                                    // Attempt to load the world map from the mapAsset.
                                    if let asset = publicRecord["mapAsset"] as? CKAsset,
                                       let assetFileURL = asset.fileURL {
                                        let data = try Data(contentsOf: assetFileURL)
                                        if let container = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMapContainer.self, from: data) {
                                            let arWorldMap = container.map
                                            WorldManager.shared.sharedARWorldMap = arWorldMap
                                            WorldManager.shared.sharedWorldName = roomName
                                            WorldManager.shared.currentWorldRecord = publicRecord 
                                            WorldManager.shared.isCollaborative = true
                                            AppState.shared.isiCloudShare = true
                                            print("Will open shared ARWorldMap in memory.")
                                            
                                            // Optionally, post a notification to navigate to your AR view.
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                NotificationCenter.default.post(name: Notifications.incomingShareMapReady, object: nil)
                                            }
                                        } else {
                                            print("Could not decode ARWorldMap from container.")
                                        }
                                    } else {
                                        print("No valid mapAsset found in the world record.")
                                    }
                                } catch {
                                    print("Error decoding ARWorldMap: \(error.localizedDescription)")
                                }
                            }
                            
                            let saveAction = UIAlertAction(title: "Save Locally", style: .default) { _ in
                                do {
                                    let localFilePath = WorldModel.appSupportDirectory.appendingPathComponent("\(roomName)_worldMap")
                                    if let asset = publicRecord["mapAsset"] as? CKAsset,
                                       let assetFileURL = asset.fileURL {
                                        let data = try Data(contentsOf: assetFileURL)
                                        try data.write(to: localFilePath, options: .atomic)
                                        print("Shared asset data written to local file: \(localFilePath.path)")
                                        WorldManager.shared.importWorldFromURL(localFilePath)
                                    } else {
                                        print("No valid map asset found to save locally.")
                                    }
                                } catch {
                                    print("Error saving shared asset data: \(error.localizedDescription)")
                                }
                            }
                            
                            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                            alert.addAction(openAction)
                            alert.addAction(saveAction)
                            alert.addAction(cancelAction)
                            
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(alert, animated: true)
                            } else {
                                print("❌ Could not find a rootViewController to present alert.")
                            }
                        }
                    }
                } else {
                    print("Collaboration URL received but recordID query item not found.")
                }
            }
            // Handle file URLs or fallback
            else if url.isFileURL && (url.pathExtension.lowercased() == "worldmap" || url.pathExtension.lowercased() == "arworld") {
                fileURLContexts.insert(context)
            } else {
                fileURLContexts.insert(context)
            }
        }
        
        if let original = originalDelegate as? UIWindowSceneDelegate,
           original.responds(to: #selector(UIWindowSceneDelegate.scene(_:openURLContexts:))) {
            original.scene?(scene, openURLContexts: fileURLContexts)
        }
        
        for context in fileURLContexts {
            NotificationCenter.default.post(name: Notifications.incomingURL, object: context.url)
        }
    }
    
    
//    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
//        var fileURLContexts = Set<UIOpenURLContext>()
//        
//        // Iterate over all incoming URLs.
//        for context in URLContexts {
//            let url = context.url
//            print("MySceneDelegate openURLContexts received: \(url.absoluteString)")
//            // If the URL contains "ckshare", treat it as a CloudKit share URL.
//            if url.absoluteString.contains("ckshare") {
//                NotificationCenter.default.post(name: Notifications.incomingShareURL, object: url)
//            }
//            // Otherwise, assume it’s a local file URL.
//            else if url.isFileURL && (url.pathExtension.lowercased() == "worldmap" || url.pathExtension.lowercased() == "arworld") {
//                fileURLContexts.insert(context)
//            } else {
//                fileURLContexts.insert(context)
//            }
//        }
//        
//        // Forward file URLs to the original delegate (if it implements scene(_:openURLContexts:)).
//        if let original = originalDelegate as? UIWindowSceneDelegate,
//           original.responds(to: #selector(UIWindowSceneDelegate.scene(_:openURLContexts:))) {
//            original.scene?(scene, openURLContexts: fileURLContexts)
//        }
//        
//        // Also post notifications so your SwiftUI code can handle them.
//        for context in fileURLContexts {
//            NotificationCenter.default.post(name: Notifications.incomingURL, object: context.url)
//        }
//    }
    
    // Forward any other scene delegate methods to the original delegate as needed.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        (originalDelegate as? UIWindowSceneDelegate)?.scene?(scene, willConnectTo: session, options: connectionOptions)
    }
    
    // (You can forward additional methods if needed.)
}
