//
//  AnchorsListView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-23.
//

import SwiftUI
import Drops
import CloudKit
import Drawer

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
    @State private var showPinPopover = false
    @State private var selectedPin: String = ""
@State private var isShowingPIN = false
    @State private var isChecking = false
    @State private var showCollaborators = false
    @State private var collaboratorNames: [String] = []
    @State private var isCollab = false
    
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
                    
                    
                }
                .ignoresSafeArea()
                
                .sheet(isPresented: $isRenaming, onDismiss: {
                    dismiss()
                }) {
                    
                    renameWorldView(worldName: worldName, worldManager: worldManager, showWarning: isCollab, newAnchors: newAnchors.count)
                        .presentationDetents(isCollab ? [.fraction(0.5)] : [.fraction(0.4)])
                    
                    
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
                                       isCollab = true

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
                        .presentationDetents([.fraction(0.4)])

                }
                .sheet(isPresented: $showPinPopover) {
                    PinView(roomName: worldName, pin: $selectedPin, isChecking: isChecking) {
                        // This runs when "Done" is pressed
                        if !isChecking && !selectedPin.isEmpty {
                            worldManager.shareWorldViaCloudKit(roomName: worldName, pin: selectedPin)
                        }
                    }
                    .presentationDetents([.fraction(0.4)])
                }
                .sheet(isPresented: $showCollaborators) {
                    // Simple SwiftUI list of collaborator names
                    NavigationStack {
                        List(collaboratorNames, id: \.self) { name in
                            Text(name)
                        }
                        .navigationTitle("Collaborators")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
                .navigationTitle(worldName)
                .toolbar {
                    
                    if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                               world.isCollaborative {
                        Button {
                               // 1) Grab the PIN from the local WorldModel
                            fetchCollaboratorsForWorld()

                           } label: {
                               Image(systemName: "link.circle.fill")
                                   .foregroundColor(.blue)
                                   .symbolEffect(.breathe)
                           }
//                           .popover(isPresented: $showPinPopover) {
//                               // 2) The popover content
//                               VStack(spacing: 10) {
//                                   if let pin = selectedPin {
//                                       Text("PIN for \(worldName)")
//                                           .font(.headline)
//                                       Text(pin)
//                                           .font(.largeTitle)
//                                           .fontWeight(.bold)
//                                           .padding()
//                                   } else {
//                                       Text("No PIN stored for this world.")
//                                           .font(.headline)
//                                           .padding()
//                                   }
//                               }
//                               .padding()
//                           }
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
                        
                            if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                               world.isCollaborative {
                                
                                AppState.shared.isCreatingLink = true
                                worldManager.shareWorldViaCloudKit(roomName: worldName, pin: "")
                            } else {
                                isChecking = false
                                showPinPopover = true
                            }
                          
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
                        
                        if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }), world.isCollaborative {
                            
                            Button {
                                print(world.pin ?? "")
                           
                               
                                selectedPin = world.pin ?? ""
                                isChecking = true
                                
                                
                                showPinPopover = true
                                
                           
                        } label: {
                            HStack {
                                Text("Show PIN")
                                Image(systemName: "key")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                
                            }
                            .font(.title2)
                        }
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
                
                VStack {
                    Spacer()
                    
                    if !newAnchors.isEmpty {
                        Drawer {
                            ZStack {
                                VisualEffectBlur(blurStyle: .systemThinMaterial)
                                VStack {
                                    RoundedRectangle(cornerRadius: 3.0)
                                        .foregroundColor(.gray)
                                        .frame(width: 30.0, height: 6.0)
                                        .padding()
                                    HStack {
                                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                            .foregroundStyle(.blue)
                                        Text("Newly added items, open AR to integrate")
                                            .font(.system(.headline, design: .rounded))
                                    }
                                    .padding(.bottom)
                                    //                                    .padding([.leading, .top])
                                    LazyVGrid(columns: columns, spacing: 10) {
                                        ForEach(newAnchors, id: \.self) { anchorName in
                                            VStack {
                                                Text(anchorName)
                                                    .padding()
                                                    .font(.system(.headline, design: .rounded))
                                                    .multilineTextAlignment(.center)
                                                    .frame(maxWidth: .infinity)
                                                    .foregroundColor(.white)
                                                    .background(Color.gray.opacity(0.8))
                                                    .cornerRadius(22)
                                                    .shadow(color: Color.black.opacity(0.3), radius: 7)
                                                    .lineLimit(1) // Ensures the text stays on one line
                                                    .truncationMode(.tail)
                                                
                                            }
                                            .onTapGesture {
                                                // For example, set findingAnchorName and dismiss the view
                                                findingAnchorName = anchorName
                                                dismiss()
                                            }
                                        }
                                    }
                                    .padding([.leading, .trailing, .bottom])
                                    
                                    Spacer()
                                }
                            }
                        }
                        .rest(at: .constant([50, 340, 600]))
                        .impact(.light)
                    }
                    
                }
                if AppState.shared.isCreatingLink {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                              .frame(maxWidth: .infinity, maxHeight: .infinity)
                              .ignoresSafeArea()

                          VStack {
                              ProgressView {
                                  Text("Creating Collaboration Link.")
                                      .font(.system(.headline, design: .rounded))

                              }
                              .padding()
                          }
                          .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand ProgressView to full height
                }
            }
        }
    }
    
    func fetchCollaboratorsForWorld() {
        guard
            let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
            world.isCollaborative,
            let publicRecordID = world.cloudRecordID
        else {
            print("World not collaborative or no cloudRecordID.")
            return
        }

        // We'll assume you have a method that fetches anchor records by worldRecordName
        // e.g. iCloudManager.shared.fetchAnchors(for: CKRecord.ID)
        let recordID = CKRecord.ID(recordName: publicRecordID)
        iCloudManager.shared.fetchNewAnchors(for: recordID) { anchorRecords in
            // anchorRecords are CKRecords for your "Anchor" type in the public DB
            var discoveredNames: [String] = []
            
            let group = DispatchGroup()
            
            for anchor in anchorRecords {
                // Each CKRecord has a 'creatorUserRecordID' if it's created by that user
                if let creatorID = anchor.creatorUserRecordID {
                    group.enter()
                    CKContainer.default().discoverUserIdentity(withUserRecordID: creatorID) { identity, error in
                        defer { group.leave() }
                        if let components = identity?.nameComponents {
                            let displayName = PersonNameComponentsFormatter().string(from: components)
                            discoveredNames.append(displayName)
                        } else {
                            // If user discovery is off, or an error occurs,
                            // you can store a fallback like "Unknown User"
                            discoveredNames.append("Unknown User")
                        }
                    }
                }
            }
            
            group.notify(queue: .main) {
                // Remove duplicates and sort
                let uniqueNames = Array(Set(discoveredNames)).sorted()
                self.collaboratorNames = uniqueNames
                print("Fetched collaborator names: \(uniqueNames)")
                // Now we can show the sheet
                self.showCollaborators = true
            }
        }
    }
}

