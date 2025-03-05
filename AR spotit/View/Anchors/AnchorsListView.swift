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
import TipKit

struct AnchorsListView: View {
    
    @StateObject var worldManager = WorldManager.shared

    @State private var anchorsByWorld: [String: [String]] = [:] // Track anchors for each world
    @Binding var worldName: String
    @Binding var findingAnchorName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isRenaming = false
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
    
    let iPadCollumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    @State private var showPinPopover = false
    @State private var selectedPin: String = ""
@State private var isShowingPIN = false
    @State private var isChecking = false
    @State private var showCollaborators = false
    @State private var collaboratorNames: [String] = []
    @State private var isCollab = false
    @State private var isDeleting = false
    @State private var isRemovingCollab = false
    @State private var currentWorld: WorldModel?
    @State private var isShowingCollabGuide = false
    
    
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
    let collabTip = StartCollaborationTip()
    let findItemTip = FindItemTip()
    
    @AppStorage("hasSeenCollabGuide") private var hasSeenCollabGuide = false

    var body: some View {
        // Anchors Section
        NavigationStack {
            ZStack {
                
                (colorScheme == .dark ? Color.black : Color.white)
                       .ignoresSafeArea()
                
                VStack {
                    
                    let snapshotPath = WorldModel.appSupportDirectory
                        .appendingPathComponent("\(worldName)_snapshot.png")
                    
                    if FileManager.default.fileExists(atPath: snapshotPath.path),
                       let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
                        
                            Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 800)
                            .clipped()
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(LinearGradient(colors: [.black.opacity(1.0), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))
                                
                            )
                            .conditionalModifier(colorScheme != .dark) { view in
                                view.colorInvert()
                            }
                            .frame(width: UIScreen.main.bounds.width, height: 400)
                            .ignoresSafeArea()
                            
                        
                        
                    }
                    
                    Spacer()
                }

                
                ScrollView(.vertical, showsIndicators: false) {
                 
                    
                    if let anchors = anchorsByWorld[worldName], !anchors.isEmpty {
                         TipView(findItemTip)
                            .padding(.horizontal)
                            .tint(colorScheme == .dark ? .white : .black)
                    }
                    
                    
                   
                    if isLoading {
                        ProgressView() {
                            Text("Loading items for \(worldName)")
                                .font(.system(.headline, design: .rounded))

                        }
                    }
                
                    
                    LazyVGrid(columns: UIDevice.isIpad ? iPadCollumns : columns, spacing: 10) {
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
                                    findItemTip.invalidate(reason: .actionPerformed)

                                    findingAnchorName = anchorName
                                    //
                                    dismiss()
                                    
                                    
                                    
                                }
                            }
                            
                        } else {
                          
                        }
                    }
                    .padding()
                    .searchable(text: $searchText,
                                              placement: .navigationBarDrawer(displayMode: .automatic),
                                prompt: "Search Items").tint(colorScheme == .dark ? .white : .black)
                    
                    
                }
                
                .sheet(isPresented: $isRenaming, onDismiss: {
                    dismiss()
                }) {
                    
                        renameWorldView(worldName: worldName, worldManager: worldManager, showWarning: isCollab, newAnchors: newAnchors.count, publicName: currentWorld?.publicRecordName ?? "")
                            .conditionalModifier(!UIDevice.isIpad) { view in
                                
                                    view.presentationDetents(isCollab ? [.fraction(0.5)] : [.fraction(0.4)])
                            }
                    
                    
                }
                .onAppear {
                  
                        
                        currentWorld = worldManager.savedWorlds.first { $0.name == worldName }
                        worldManager.getAnchorNames(for: worldName) { fetchedAnchors in
                               DispatchQueue.main.async {
                                   anchorsByWorld[worldName] = fetchedAnchors
                                   isLoading = false
                                   
                                   // Now, if the world is collaborative, fetch new anchors
                                   if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                                      world.isCollaborative,
                                      let recordName = world.publicRecordName {
                                       isCollab = true

                                       iCloudManager.shared.fetchNewAnchors(for: recordName) { records in
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
                    
                    
                    print(worldName)

                    
                }
          
                .sheet(isPresented: $isShowingQR) {
                   
                        QRview(roomName: worldName)
                            .conditionalModifier(!UIDevice.isIpad) { view in
                                 view.presentationDetents([.fraction(0.4)])
                             }
                    

                }
                .sheet(isPresented: $showPinPopover) {
                   
                        PinView(roomName: worldName, pin: $selectedPin, isChecking: isChecking) {
                            // This runs when "Done" is pressed
                            if !isChecking && !selectedPin.isEmpty {
                                worldManager.shareWorldViaCloudKit(roomName: worldName, pin: selectedPin)
                            }
                        }
                        .conditionalModifier(!UIDevice.isIpad) { view in
                             view.presentationDetents([.fraction(0.5)])
                         }
                    
                }
                .sheet(isPresented: $isShowingCollabGuide) {
                    CollaborationGuideView() {
                        if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                           world.isCollaborative {
                            
                            AppState.shared.isCreatingLink = true
                            worldManager.shareWorldViaCloudKit(roomName: worldName, pin: "")
                        } else {
                            isChecking = false
                            showPinPopover = true
                        }
                        
                        hasSeenCollabGuide = true
                    }
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
                .sheet(isPresented: $isDeleting) {
                   
                        DeleteConfirm(isCollab: isCollab, roomName: worldName) { name in
                            worldManager.deleteWorld(roomName: worldName, publicName: currentWorld?.publicRecordName ?? "") {
                                print("Deletion process completed.")
                                let drop = Drop.init(title: "\(worldName) deleted!")
                                
                                Drops.show(drop)
                                
                                HapticManager.shared.notification(type: .success)
                                
                                isDeleting = false
                                
                            }
                        }
                        .conditionalModifier(!UIDevice.isIpad) { view in
                             view.presentationDetents([.fraction(0.5)])
                         }
                    
                }
                .sheet(isPresented: $isRemovingCollab) {
                   
                        RemoveCollabView(roomName: worldName) {
                        
                            worldManager.removeCollab(roomName: worldName)
                           
                        }
                        .conditionalModifier(!UIDevice.isIpad) { view in
                             view.presentationDetents([.fraction(0.5)])
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
                                   .symbolRenderingMode(.palette)
                                   .foregroundStyle(.white, .blue)
                                   .font(.headline)
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
                            collabTip.invalidate(reason: .actionPerformed)

                            if !hasSeenCollabGuide {
                                isShowingCollabGuide = true
                            } else {
                                if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }),
                                   world.isCollaborative {
                                    
                                    AppState.shared.isCreatingLink = true
                                    worldManager.shareWorldViaCloudKit(roomName: worldName, pin: "")
                                } else {
                                    isChecking = false
                                    showPinPopover = true
                                }
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
                       
                        
                       
                        
                        if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }), world.isCollaborative {
                            
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
                            
                            Button {
                                isRemovingCollab = true
                        } label: {
                            HStack {
                                Text("Remove Collaboration")
                                Image(systemName: "person.2.slash")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                
                            }
                            .font(.title2)
                        }
                    }
                         
                        Button(role: .destructive) {
                            isDeleting = true

                         
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
                    .popoverTip(collabTip)
                  
                }
                
                VStack {
                    Spacer()
                    
                    if !newAnchors.isEmpty {
                        Drawer {
                            ZStack {
                                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                                    .shadow(color: colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4), radius: 10)

                                VStack {
                                    RoundedRectangle(cornerRadius: 3.0)
                                        .foregroundColor(.gray)
                                        .frame(width: 30.0, height: 6.0)
                                        .padding()
                                    HStack {
                                       
                                        Text("Newly added items")
                                            .font(.system(.title2, design: .rounded))
                                            .bold()
                                        
                                        Image(systemName: "circle.badge.plus")
                                            .font(.system(.title3, design: .rounded))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.green, colorScheme == .dark ? .white : .black)                                            .bold()
                                            .symbolEffect(.pulse)
                                            .shadow(color: .green.opacity(0.8), radius: 10)
                                    }
                                    .padding(.bottom)
                                    
                                    
                                    Button {
                                        isOpeningFromAnchorListView = true
                                        dismiss()
                                    } label: {
                                        Text("Open \(worldName) in AR")
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                                            .bold()
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 55)
                                            .background(Color.primary.opacity(1))
                                            .cornerRadius(10)
                                    }

                                    .padding([.horizontal, .top])
                                    Text("Open \(worldName) to verify & integrate and save these items to make them available for public use.")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
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
                        .rest(at: .constant([60, 340, 600]))
                        .impact(.light)
                    }
                    
                }
                
                if let anchors = anchorsByWorld[worldName], anchors.filter({ $0 != "guide" }).isEmpty {
                    VStack {
                        Spacer()
                        ContentUnavailableView {
                            Label("No Items found", systemImage: "exclamationmark.warninglight.fill")
                                .font(.system(.title2, design: .rounded))
                            
                        } description: {
                            Text("Open Area to add new items.")
                                .font(.system(.headline, design: .rounded))

                        }
                        Spacer()
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
       
        iCloudManager.shared.fetchNewAnchors(for: world.publicRecordName ?? "") { anchorRecords in
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

