//
//  AnchorsListView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-23.
//

import SwiftUI
import Drops
import CloudKit

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
    @State private var isLoading = true
    @State private var isShowingQR = false
    @State private var searchText: String = ""
    @State private var newAnchors: [String] = []
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
    
    var filteredAnchors: [String] {
         guard let anchors = anchorsByWorld[worldName] else { return [] }
         return anchors.filter { anchor in
             guard anchor != "guide" else { return false }
             // Remove any emojis from the anchor name before searching.
             let cleanAnchor = anchor.filter { !$0.isEmoji }
             return searchText.isEmpty || cleanAnchor.localizedCaseInsensitiveContains(searchText)
         }
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
                    if isLoading {
                        ProgressView() {
                            Text("Loading items for \(worldName)")
                                .font(.system(.headline, design: .rounded))

                        }
                    }
                    if let anchors = anchorsByWorld[worldName], anchors.filter({ $0 != "guide" }).isEmpty {
                        VStack {
                            ContentUnavailableView {
                                Label("No Items found", systemImage: "exclamationmark.warninglight.fill")
                                    .font(.system(.title2, design: .rounded))
                                
                            } description: {
                                Text("Open Area to add new items.")
                                //   .font(.system(design: .rounded))
                                
                            }
                        }

                    }
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        if let anchors = anchorsByWorld[worldName], !anchors.isEmpty {
//                            // Filter out "guide" anchors
//                            
//                            
//                            //                    let anchors = filteredAnchors(for: world.name)
//                            let filteredAnchors = anchors.filter { $0 != "guide" }
                            // Show non-guide anchors
                            ForEach(Array(filteredAnchors.enumerated()), id: \.0) { index, anchorName in
                                VStack {
                                    // Extract and display the emoji if present
                                    let emoji = extractEmoji(from: anchorName)
                                    HStack {
                                        Text(emoji ?? "📍")
                                            .font(.system(size: 50))
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)

                                    // Display the anchor name without the emoji
                                    let cleanAnchorName = anchorName.filter { !$0.isEmoji }
                                    Text(cleanAnchorName)
                                        .font(.system(.headline, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .bold()
                                        .foregroundStyle(.white)
                                    
                                }
                                .frame(maxWidth: .infinity)
                                
                                .frame(height: 90)
                                .padding()
                                .background(
                                    VStack {
                                        Spacer().frame(height: 55)

                                        Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍")).opacity(0.9).frame(height: 55) // Use extracted color
                                            .cornerRadius(22)

                                    }
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
                          
                        }
                    }
                    .padding()
                    .padding(.top, -60)
                    .searchable(text: $searchText,
                                              placement: .navigationBarDrawer(displayMode: .automatic),
                                prompt: "Search Anchors").tint(colorScheme == .dark ? .white : .black)
                    
                    
                    if !newAnchors.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Newly added items, open AR to integrate")
                                .font(.headline)
                                .padding([.leading, .top])
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(newAnchors, id: \.self) { anchorName in
                                    VStack {
                                        // Extract emoji if available, fallback icon otherwise.
                                        let emoji = extractEmoji(from: anchorName) ?? "📍"
                                        HStack {
                                            Text(emoji)
                                                .font(.system(size: 50))
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        // Display the anchor name (without emoji)
                                        let cleanAnchorName = anchorName.filter { !$0.isEmoji }
                                        Text(cleanAnchorName)
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.white)
                                    }
                                    .frame(height: 90)
                                    .padding()
                                    .background(
                                        VStack {
                                            Spacer().frame(height: 55)

                                            Color.gray.opacity(0.8)
                                                .cornerRadius(22)

                                        }
                                       
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 7)
                                    .onTapGesture {
                                        // For example, set findingAnchorName and dismiss the view
                                        findingAnchorName = anchorName
                                        dismiss()
                                    }
                                }
                            }
                            .padding([.leading, .trailing])
                        }
                    }
                    
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
                        worldManager.getAnchorNames(for: worldName) { fetchedAnchors in
                               DispatchQueue.main.async {
                                   anchorsByWorld[worldName] = fetchedAnchors
                                   isLoading = false
                                   
                                   // Now, if the world is collaborative, fetch new anchors
                                   if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                                      world.isCollaborative,
                                      let publicRecordID = world.cloudRecordID {
                                       
                                       let recordID = CKRecord.ID(recordName: publicRecordID)
                                       iCloudManager.shared.fetchNewAnchors(for: recordID) { records in
                                           DispatchQueue.main.async {
                                               // Extract new anchor names from the records (assuming each record has a "name" field)
                                               let fetchedNewAnchorNames = records.compactMap { $0["name"] as? String }
                                               let existingAnchors = anchorsByWorld[worldName] ?? []
                                               
                                               // Only add new anchors that are not already present
                                               newAnchors = fetchedNewAnchorNames.filter { !existingAnchors.contains($0) }
                                               
                                               print("Fetched \(newAnchors.count) new collaborative anchors.")
                                           }
                                       }
                                   }
                               }
                           }
                    }
                    print(worldName)

                    
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
                .sheet(isPresented: $isShowingQR) {
                    QRview(roomName: worldName)
                        .presentationDetents([.fraction(0.5)])

                }
                .navigationTitle(worldName)
                .toolbar {
                    
                    if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                               world.isCollaborative {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.blue)
                                    .symbolEffect(.breathe)
                            }
                    
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
                        
                        Button {
                            worldManager.shareWorldViaCloudKit(roomName: worldName)
                        } label: {
                            HStack {
                                Text("Share iCloud link")
                                Image(systemName: "link.icloud")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                
                            }
                            .font(.title2)
                            
                        }
                        
                        Button {
                            isShowingQR = true
                        } label: {
                            HStack {
                                Text("Share QR code")
                                Image(systemName: "qrcode")
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

