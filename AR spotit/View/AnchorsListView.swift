//
//  AnchorsListView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-23.
//

import SwiftUI
import Drops

struct AnchorsListView: View {
    
    @ObservedObject var worldManager: WorldManager

    @State private var anchorsByWorld: [String: [String]] = [:] // Track anchors for each world
    @Binding var worldName: String
    @Binding var findingAnchorName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isRenaming = false
    @State private var isOpeningWorld = false
    @State private var showFocusedAnchor: Bool = false
    @Binding var isOpeningFromAnchorListView: Bool
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ] // Two flexible columns
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
                if char.isEmoji {
                    return String(char)
                }
            }
            return nil
    }
    
    
    var body: some View {
        // Anchors Section
        NavigationStack {
            ZStack {
                
                (colorScheme == .dark ? Color.black : Color.white)
                       .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                 
                    
                    
                    
                    
                    ZStack {
                        
                        
                        // (NEW) Show snapshot preview if it exists
                        let snapshotPath = WorldModel.appSupportDirectory
                            .appendingPathComponent("\(worldName)_snapshot.png")
                        
                        if FileManager.default.fileExists(atPath: snapshotPath.path),
                           let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
                            
                            if colorScheme == .dark {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 400)
                                    .clipped()
                                    .cornerRadius(15)
                                    .overlay(
                                                RoundedRectangle(cornerRadius: 15)
                                                    .fill(LinearGradient(colors: [.black.opacity(1.0), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))

                                            )
                                
                            } else {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 400)
                                    .clipped()
                                    .cornerRadius(15)
                                    .overlay(
                                                RoundedRectangle(cornerRadius: 15)
                                                    .fill(LinearGradient(colors: [.black.opacity(1.0), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))

                                            )
                                    .colorInvert()
                                
                            }
                            
                        } else {
                            // fallback if no image
                            Text("No Snapshot")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        
                        
                        
                
                        
                        
                        
                        
                        
                        
                    }
                    .frame(width: UIScreen.main.bounds.width, height: 400)
                    
                    
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        if let anchors = anchorsByWorld[worldName], !anchors.isEmpty {
                            // Filter out "guide" anchors
                            
                            
                            //                    let anchors = filteredAnchors(for: world.name)
                            let filteredAnchors = anchors.filter { $0 != "guide" }
                            // Show non-guide anchors
                            ForEach(Array(filteredAnchors.enumerated()), id: \.0) { index, anchorName in
                                VStack {
                                    // Extract and display the emoji if present
                                    let emoji = extractEmoji(from: anchorName)
                                    Text(emoji ?? "📍")
                                        .font(.system(size: 50))
                                    // Display the anchor name without the emoji
                                    let cleanAnchorName = anchorName.filter { !$0.isEmoji }
                                    Text(cleanAnchorName)
                                        .font(.system(.headline, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .bold()
                                        .foregroundStyle(.white)
                                    
                                }
                                .frame(maxWidth: .infinity)
                                
                                .frame(height: 110)
                                .padding()
                                .background(
                                    Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍")).opacity(0.9) // Use extracted color
                                )
                                .cornerRadius(22)
                                .shadow(color: Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍")).opacity(0.7), radius: 7)
                                .onTapGesture {
                                    
                                    findingAnchorName = anchorName
                                    //
                                    dismiss()
                                    
                                    
                                    
                                }
                            }
                            
                        } else {
                            Text("No anchors found.")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .padding(.top, -60)
                    
                    
                }
                .ignoresSafeArea()
                .sheet(isPresented: $isRenaming, onDismiss: {
                    dismiss()
                }) {
                    
                    renameWorldView(worldName: $worldName, worldManager: worldManager)
                        .presentationDetents([.fraction(0.4)])
                    
                    
                }
                .onAppear {
                    // Fetch anchors for this specific world
                    worldManager.loadSavedWorlds {
                        
                    }
                    print(worldName)
                    worldManager.checkAndSyncIfNewer(for: worldName) {
                          // 2) Now safely fetch anchors
                          worldManager.getAnchorNames(for: worldName) { fetchedAnchors in
                              DispatchQueue.main.async {
                                  anchorsByWorld[worldName] = fetchedAnchors
                              }
                          }
                      }
                    
                }
                .sheet(isPresented: $isOpeningWorld, onDismiss: {
                    worldManager.loadSavedWorlds {
                        
                    }
                    
                    worldManager.getAnchorNames(for: worldName) { fetchedAnchors in
                            DispatchQueue.main.async {
                                anchorsByWorld[worldName] = fetchedAnchors
                            }
                        }
                    
                }) {
                    ContentView(
                        currentRoomName: worldName,
                        directLoading: true,
                        findAnchor: $findingAnchorName,
                        isShowingFocusedAnchor: $showFocusedAnchor
                    )
                    .interactiveDismissDisabled()
                    
                    .onDisappear {
                           findingAnchorName = ""
                           print("ContentView dismissed")
                       }
                }
                .navigationTitle(worldName)
                .toolbar {
                    Button(action: {
                        
                        //                    updateRoomName = world.name
//                                            worldManager.isShowingAll = true
                    //    isOpeningWorld = true
                        isOpeningFromAnchorListView = true
                        dismiss()

                        //                    selectedWorld = world // Set the selected world
                    }) {
                        Image(systemName: "arkit")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                    Menu {
                        Button {
                            
                            isRenaming.toggle()
                        } label: {
                            HStack {
                                Text("Rename")
                                Image(systemName: "character.cursor.ibeam")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                            }
                        }
                        
                        Button {
                            worldManager.shareWorld(currentRoomName: worldName)
                        } label: {
                            HStack {
                                Text("Share")
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                
                            }
                            .font(.title2)
                            
                        }
                        
                        Button(role: .destructive) {
                            worldManager.deleteWorld(roomName: worldName) {
                                dismiss()
                                print("Deletion process completed.")
                                let drop = Drop.init(title: "\(worldName) deleted!")
                                Drops.show(drop)
                            }
                        } label: {
                            HStack {
                                Text("Delete")
                                    .foregroundColor(.red) // Use this for text
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.red)
                                
                            }
                            .font(.title2)
                            
                        }
                        
                        
                        
                        
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
            }
        }
    }
}

