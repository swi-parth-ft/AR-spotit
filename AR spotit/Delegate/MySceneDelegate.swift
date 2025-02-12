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
        
        // Iterate over all incoming URLs.
        for context in URLContexts {
            let url = context.url
            print("MySceneDelegate openURLContexts received: \(url.absoluteString)")
            // If the URL contains "ckshare", treat it as a CloudKit share URL.
            if url.absoluteString.contains("ckshare") {
                NotificationCenter.default.post(name: Notifications.incomingShareURL, object: url)
            }
            // Otherwise, assume it’s a local file URL.
            else if url.isFileURL && (url.pathExtension.lowercased() == "worldmap" || url.pathExtension.lowercased() == "arworld") {
                fileURLContexts.insert(context)
            } else {
                fileURLContexts.insert(context)
            }
        }
        
        // Forward file URLs to the original delegate (if it implements scene(_:openURLContexts:)).
        if let original = originalDelegate as? UIWindowSceneDelegate,
           original.responds(to: #selector(UIWindowSceneDelegate.scene(_:openURLContexts:))) {
            original.scene?(scene, openURLContexts: fileURLContexts)
        }
        
        // Also post notifications so your SwiftUI code can handle them.
        for context in fileURLContexts {
            NotificationCenter.default.post(name: Notifications.incomingURL, object: context.url)
        }
    }
    
    // Forward any other scene delegate methods to the original delegate as needed.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        (originalDelegate as? UIWindowSceneDelegate)?.scene?(scene, willConnectTo: session, options: connectionOptions)
    }
    
    // (You can forward additional methods if needed.)
}
