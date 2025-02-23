//
//  ImportWorldSheet.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-14.
//


import SwiftUI
import Drops

struct ImportWorldSheet: View {
    @EnvironmentObject var worldManager: WorldManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Spacer()
                Text("Start with naming this area. e.g. Bedroom, Library 2nd floor, etc")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                
                TextField("Enter world name", text: $worldManager.tempWorldName)
                    .focused($isTextFieldFocused)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(height: 55)
                    .background(Color.secondary.opacity(0.4))
                    .cornerRadius(10)
                    .tint(.primary)
                    .padding(.horizontal)
                    .onAppear {
                                isTextFieldFocused = true
                            }
                
                Button(action: {
                    saveWorld()
                    worldManager.loadSavedWorlds {
                        
                    }
                    AppState.shared.isWorldUpdated.toggle() // Notify WorldsView
                    let drop = Drop.init(title: "\(worldManager.tempWorldName) Saved!")
                    Drops.show(drop)
                    
                    
                }) {
                    Text("Save")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary.opacity(1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

            }
            .padding()
            .navigationTitle("Save new area")
            .toolbar {
                Button {
              //      isShowingGuide.toggle()
                } label: {
                    Image(systemName: "lightbulb.circle")
                        .font(.title2)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }
        }
    }
    private func saveWorld() {
        // Ensure we have a valid URL from which to import the world.
        guard let sourceURL = worldManager.importWorldURL else {
            print("No URL to import from.")
            return
        }
        
        // Determine the new world name.
        let newWorldName = worldManager.tempWorldName.isEmpty ? "Untitled World" : worldManager.tempWorldName
        
        var fileData: Data?
        
        // First, try to read directly from the source URL.
        do {
            // For file provider URLs, attempt security-scoped access.
            if sourceURL.startAccessingSecurityScopedResource() {
                defer { sourceURL.stopAccessingSecurityScopedResource() }
                fileData = try Data(contentsOf: sourceURL)
                print("✅ Successfully read data directly from the file URL.")
            } else {
                print("❌ Failed to gain security-scoped access to the file.")
            }
        } catch {
            print("❌ Error reading data directly from URL: \(error.localizedDescription)")
        }
        
        // If reading directly failed (e.g. due to permission errors), try copying the file into your container.
        if fileData == nil {
            // Define a destination URL inside your app’s container.
            // Use the same naming convention as your local load functions.
            let destinationURL = WorldModel.appSupportDirectory.appendingPathComponent("\(newWorldName)_imported")
            // (If your working local files have no extension, leave it out. Otherwise, add an extension if needed.)
            
            do {
                // Copy the file from the source URL to your container.
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                print("✅ File copied to local container: \(destinationURL.path)")
                fileData = try Data(contentsOf: destinationURL)
                print("✅ Successfully read data from the copied file.")
            } catch {
                print("❌ Failed to copy or read file: \(error.localizedDescription)")
            }
        }
        
        // If we have data, pass it to your world manager to save/import the world.
        if let data = fileData {
            worldManager.saveImportedWorld(data: data, worldName: newWorldName)
            print("✅ Imported file read successfully.")
        } else {
            print("❌ Could not read file data from imported URL.")
        }
        
        // Dismiss the sheet.
        dismiss()
    }
}
