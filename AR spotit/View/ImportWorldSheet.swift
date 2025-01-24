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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Start with naming this area. e.g. Bedroom, Library 2nd floor, etc")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                
                TextField("Enter world name", text: $worldManager.tempWorldName)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(height: 55)
                    .background(Color.secondary.opacity(0.4))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
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
        guard let url = worldManager.importWorldURL else {
            print("No URL to import from.")
            return
        }

        // Call the saving logic with the user-provided name
        let newWorldName = worldManager.tempWorldName.isEmpty ? "Untitled World" : worldManager.tempWorldName
        do {
            let data = try Data(contentsOf: url)
            worldManager.saveImportedWorld(data: data, worldName: newWorldName)
        } catch {
            print("Error reading data from URL: \(error.localizedDescription)")
        }

        dismiss() // Close the sheet
    }
}
