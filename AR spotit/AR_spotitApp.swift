//
//  AR_spotitApp.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//

import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight


class AppState: ObservableObject {
    static let shared = AppState() // Singleton instance
    @Published var isWorldUpdated: Bool = false {
    
        didSet {
            print("isWorldUpdated changed to: \(isWorldUpdated)")
        }
    }
    
    
    
    
    
}


@main
struct AR_spotitApp: App {

    // Ideally pass WorldManager down via environment or as a singleton
    @StateObject var worldManager = WorldManager()
    @State private var isActive = false // Tracks if the splash screen is active

    var body: some Scene {
        WindowGroup {
            ZStack {
                            // Main Content View
                            WorldsView()
//                    .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)
                    .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)

                                // .environmentObject(worldManager)
                                .onOpenURL { url in
                                    handleIncomingWorldFile(url)
                                }
                                .sheet(isPresented: $worldManager.isImportingWorld) {
                                    ImportWorldSheet()
                                        .environmentObject(worldManager)
                                        .presentationDetents([.fraction(0.4)])
                                }

                            // Splash Screen
                            if !isActive {
                                PhysicsDotsAnimationView()
                                    .transition(.opacity) // Fade in/out transition
                                    .zIndex(1) // Ensure it's on top
                            }
                        }
                        .onAppear {
                            // Delay the splash screen for 1 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    self.isActive = true // Hide splash screen
                                }
                            }
                        }
        }
       
    }

    private func handleIncomingWorldFile(_ url: URL) {
        
        // Make sure it’s the right type (e.g., .arworld, .worldmap, etc.)
        guard url.pathExtension == "arworld" || url.pathExtension == "worldmap" else {
            print("Unknown file type: \(url.pathExtension)")
            return
        }
        

        // Hand off the URL to a helper in your WorldManager
        worldManager.importWorldFromURL(url) 
    }
    
    func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        print("Handling Spotlight user activity")

        guard let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            print("No unique identifier found in user activity")
            return
        }

        let worldPrefix = "com.parthant.AR-spotit."
        let itemPrefix = "item.com.parthant.AR-spotit."

        if uniqueIdentifier.hasPrefix(worldPrefix) {
            let worldName = String(uniqueIdentifier.dropFirst(worldPrefix.count))
            Task {
                if worldManager.savedWorlds.isEmpty {
                    print("savedWorlds is empty. Waiting for worlds to load...")
                    await worldManager.loadSavedWorldsAsync()
                }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("OpenWorldNotification"),
                        object: nil,
                        userInfo: ["worldName": worldName]
                    )
                    print("Selected world set to \(worldName) via Spotlight")
                }
            }
        } else if uniqueIdentifier.hasPrefix(itemPrefix) {
            // Remove the prefix, then split the remaining string at the first "."
                  let remaining = uniqueIdentifier.dropFirst(itemPrefix.count)
                  let components = remaining.split(separator: ".", maxSplits: 1)
                  guard components.count == 2 else {
                      print("Could not parse searchable item identifier: \(uniqueIdentifier)")
                      return
                  }
                  let worldName = String(components[0])
                  let itemName = String(components[1])
                  
                  Task {
                      if worldManager.savedWorlds.isEmpty {
                          print("savedWorlds is empty. Waiting for worlds to load...")
                          await worldManager.loadSavedWorldsAsync()
                      }
                      DispatchQueue.main.async {
                          NotificationCenter.default.post(
                              name: Notification.Name("FindItemNotification"),
                              object: nil,
                              userInfo: ["itemName": itemName, "worldName": worldName]
                          )
                          print("Selected item \(itemName) in world \(worldName) via Spotlight")
                      }
                  }
        } else {
            print("Unique identifier does not match known prefixes")
        }
    }
   
}
