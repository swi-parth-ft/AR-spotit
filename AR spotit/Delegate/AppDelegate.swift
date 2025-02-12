//
//  AppDelegate.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-11.
//

import UIKit
import CloudKit


class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        CKContainer.default().accountStatus { status, error in
            if let error = error {
                print("Error checking CloudKit account status: \(error.localizedDescription)")
            } else {
                print("CloudKit account status: \(status)")
                let container = CKContainer.default()
                
                print("🔍 Container Identifier: \(container.containerIdentifier ?? "Unknown")")
            }
        }
        return true
    }
    
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("AppDelegate open URL: \(url.absoluteString)")
        // Forward URL handling if needed, for example:
        NotificationCenter.default.post(name: Notifications.incomingURL, object: url)
        return true
    }
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            print("AppDelegate continue userActivity: \(url.absoluteString)")
            NotificationCenter.default.post(name: Notifications.incomingURL, object: url)
        }
        return true
    }
}
