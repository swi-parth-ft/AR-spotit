import UIKit
import CloudKit

class MySceneDelegate: NSObject, UIWindowSceneDelegate {
    var originalDelegate: UISceneDelegate?
    
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        NotificationCenter.default.post(name: Notifications.incomingShareURL, object: cloudKitShareMetadata)
        
        (originalDelegate as? UIWindowSceneDelegate)?.windowScene?(windowScene, userDidAcceptCloudKitShareWith: cloudKitShareMetadata)
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        var fileURLContexts = Set<UIOpenURLContext>()
        
        for context in URLContexts {
            let url = context.url
            print("MySceneDelegate openURLContexts received: \(url.absoluteString)")
            
            // Handle CloudKit share URLs as before
            if url.absoluteString.contains("ckshare") {
                NotificationCenter.default.post(name: Notifications.incomingShareURL, object: url)
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

    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        (originalDelegate as? UIWindowSceneDelegate)?.scene?(scene, willConnectTo: session, options: connectionOptions)
    }
    
}
