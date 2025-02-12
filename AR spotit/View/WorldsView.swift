import SwiftUI
import Drops
import AppIntents
import CoreSpotlight
import MobileCoreServices

struct WorldsView: View {
    
  
    
    @StateObject var worldManager = WorldManager()
    @State private var selectedWorld: WorldModel? // Track which world is selected for adding anchors
    @State private var anchorsByWorld: [String: [String]] = [:] // Track anchors for each world
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ] // Two flexible columns
    @State private var isAddingNewRoom = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isFindingAnchor = false
    @State private var findingAnchorName: String = ""
    @State private var showFocusedAnchor: Bool = false
    @State private var isRenaming = false
    @State private var currentName = ""
    @State private var isTestingAudio = false
    @State private var searchText = "" // New State for Search Text
    @State private var sortingOption: SortingOption = .name // Sorting Option

    @ObservedObject var appState = AppState.shared // Observe AppState
    @State private var roomName: String = ""
@State private var updateRoomName: String?
    @State private var isShowingAnchors: Bool = false
    @State private var selectedImage: UIImage?
    @State private var isOpeningFromAnchorListView = false
    
    @Namespace private var animationNamespace
    enum SortingOption {
         case name
         case lastModified
     }
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
                if char.isEmoji {
                    return String(char)
                }
            }
            return nil
    }
    
    var filteredWorlds: [WorldModel] {
        
        let sortedWorlds: [WorldModel]
             switch sortingOption {
             case .name:
                 sortedWorlds = worldManager.savedWorlds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
             case .lastModified:
                 sortedWorlds = worldManager.savedWorlds.sorted { $0.lastModified > $1.lastModified }
             }
        
        
        if searchText.isEmpty {
                   return sortedWorlds
               } else {
                   return sortedWorlds.filter { world in
                       world.name.localizedCaseInsensitiveContains(searchText) ||
                       (anchorsByWorld[world.name]?.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ?? false)
                   }
               }
    }

    func filteredAnchors(for worldName: String) -> [String] {
        if searchText.isEmpty {
                return anchorsByWorld[worldName] ?? [] // Show all anchors when search is empty
            }
        // If searchText matches the worldName, return all anchors for this world
        if worldName.localizedCaseInsensitiveContains(searchText) {
            return anchorsByWorld[worldName] ?? []
        }
        // Otherwise, filter anchors by searchText
        return (anchorsByWorld[worldName]?.filter { $0.localizedCaseInsensitiveContains(searchText) }) ?? []
    }
    
    init()  {
        
            
            var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle) /// the default large title font
            titleFont = UIFont(
                descriptor:
                    titleFont.fontDescriptor
                    .withDesign(.rounded)? /// make rounded
                    .withSymbolicTraits(.traitBold) /// make bold
                    ??
                    titleFont.fontDescriptor, /// return the normal title if customization failed
                size: titleFont.pointSize
            )
            
            /// set the rounded font
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
        }
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    
                  
                    if filteredWorlds.isEmpty && searchText.isEmpty {
                        VStack {
                            Spacer()
                            ContentUnavailableView {
                                Label("No Area saved yet!", systemImage: "viewfinder")
                                    .font(.system(.title2, design: .rounded))
                                
                            } description: {
                                Text("Start adding a area by tapping the plus \(Image(systemName: "plus.circle")) button.")
                                //   .font(.system(design: .rounded))
                                
                            }
                            Spacer()
                        }
                        .frame(height: UIScreen.main.bounds.height * 0.7)

                    }
                    
                        
                        
                        if !searchText.isEmpty && filteredWorlds.isEmpty{
                            VStack {
                                Spacer()
                                ContentUnavailableView {
                                Label("No Results for '\(searchText)'", systemImage: "magnifyingglass")
                                    .font(.system(.title2, design: .rounded))
                                
                            } description: {
                                Text("Check spelling or try new search.")
                                //   .font(.system(design: .rounded))
                                
                            }
                                
                            
                            Spacer()
                            
                        }
                            .frame(height: UIScreen.main.bounds.height * 0.7)

                    }
                    
                    
                    ForEach(filteredWorlds) { world in
                        VStack(alignment: .leading) {
                            
                            ZStack {
                                
                            
                                // (NEW) Show snapshot preview if it exists
                                let snapshotPath = WorldModel.appSupportDirectory
                                    .appendingPathComponent("\(world.name)_snapshot.png")
                                
                                if FileManager.default.fileExists(atPath: snapshotPath.path),
                                   let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
                                    
                                    if colorScheme == .dark {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 200)
                                            .clipped()
                                            .cornerRadius(15)
                                            .overlay(
                                                        RoundedRectangle(cornerRadius: 15)
                                                            .fill(LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))
                                                            
                                                          
                                                    )
                                            .padding(.horizontal)
                                            .shadow(color: .white.opacity(0.4), radius: 5)
                                    } else {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 200)
                                            .clipped()
                                            .cornerRadius(15)
                                            .overlay(
                                                        RoundedRectangle(cornerRadius: 15)
                                                            .fill(LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))
                                                            
                                                          
                                                    )
                                            .padding(.horizontal)
                                            .colorInvert()
                                            .shadow(radius: 5)

                                    }

                                } else {
                                    // fallback if no image
                                    Text("No Snapshot")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                }
                                
                                VStack {
                                    Spacer()
                                    // Room Title
                                    HStack {
                                      
                                            Text(world.name)
                                                .font(.system(.title2, design: .rounded))
                                                .bold()
                                        
                                        Spacer()
                                        Button(action: {
                                            updateRoomName = world.name
                                            worldManager.isShowingAll = true
                                            selectedWorld = world // Set the selected world
                                        }) {
                                            Image(systemName: "arkit")
                                                .font(.title)
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                        }
                                        
                                        Menu {
                                            Button {
                                                HapticManager.shared.impact(style: .medium)

                                                isRenaming.toggle()
                                            } label: {
                                                HStack {
                                                    Text("Rename")
                                                    Image(systemName: "character.cursor.ibeam")
                                                        .font(.title)
                                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                                }
                                            }
                                            
                                            Button {
                                                worldManager.shareWorld(currentRoomName: world.name)
                                                HapticManager.shared.impact(style: .medium)

                                            } label: {
                                                HStack {
                                                    Text("Share")
                                                    Image(systemName: "square.and.arrow.up")
                                                        .font(.title)
                                                        .foregroundStyle(colorScheme == .dark ? .white : .black)

                                                }
                                                .font(.title)
                                                
                                            }
                                            
                                            Button {
                                                worldManager.shareWorldViaCloudKit(roomName: world.name)
                                            } label: {
                                                HStack {
                                                    Text("Share iCloud link")
                                                    Image(systemName: "link.icloud")
                                                        .font(.title2)
                                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                                    
                                                }
                                                .font(.title2)
                                                
                                            }
                                            
                                            Button(role: .destructive) {
                                                worldManager.deleteWorld(roomName: world.name) {
                                                    print("Deletion process completed.")
                                                    let drop = Drop.init(title: "\(world.name) deleted!")
                                                    Drops.show(drop)
                                                    HapticManager.shared.notification(type: .success)

                                                }
                                            } label: {
                                                HStack {
                                                    Text("Delete")
                                                        .foregroundColor(.red) // Use this for text
                                                    Image(systemName: "trash.fill")
                                                        .foregroundStyle(.red)
                                                        
                                                }
                                                .font(.title)
                                                
                                            }
                                            
                                            .onAppear {
                                                currentName = world.name
                                            }
                                            
                                            
                                            
                                            
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.title)
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                        }
                                        

                                    }
                                    .padding(.horizontal)
                                }
                              
                                .padding()


                                
                            }
                            .frame(height: 200)
                            .padding(.vertical, 10)
                            .matchedTransitionSource(id: "zoom-\(world.name)", in: animationNamespace)
                            .onTapGesture {
                                
                                currentName = world.name
                                HapticManager.shared.impact(style: .heavy)

                              //  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    
                                    isShowingAnchors = true
                              //  }
                            }
                            
                           
                            if searchText != "" {
                                
                                
                                // Anchors Section
                                ScrollView(.vertical, showsIndicators: false) {
                                    LazyVGrid(columns: columns, spacing: 10) {
                                        if let anchors = anchorsByWorld[world.name], !anchors.isEmpty {
                                            // Filter out "guide" anchors
                                            
                                            
                                            let anchors = filteredAnchors(for: world.name)
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
                                                    worldManager.isShowingAll = false
                                                    isFindingAnchor = true
                                                    findingAnchorName = anchorName
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        selectedWorld = world
                                                    }
                                                    
                                                }
                                            }
                                            
                                        } else {
                                            Text("No anchors found.")
                                                .foregroundColor(.secondary)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    
                                }
                                .onAppear {
                                    
                                 
                                }
                            }
                        }
                        .onAppear {
                            // Fetch anchors for this specific world
                            if anchorsByWorld[world.name] == nil || anchorsByWorld[world.name]?.isEmpty == true {
                                worldManager.getAnchorNames(for: world.name) { fetchedAnchors in
                                    DispatchQueue.main.async {
                                        anchorsByWorld[world.name] = fetchedAnchors
                                        
                                        let tupleAnchors = fetchedAnchors.map { (anchorName: $0, worldName: world.name) }
                                        worldManager.indexItems(anchors: tupleAnchors)
                                        
                                    }
                                   
                                }
                            }
                        }
              
                    }
                }
             
                .onAppear {
                    if currentName == "" {
                        worldManager.loadSavedWorlds {
             
                        }
                    }
          
                }
                .onChange(of: AppState.shared.isWorldUpdated) {
                    worldManager.loadSavedWorlds {
                        
                    }

                }
    
                .padding(.top)
                .sheet(isPresented: $isRenaming) {
                    
                    renameWorldView(worldName: $currentName, worldManager: worldManager)
                        .presentationDetents([.fraction(0.4)])

                        
                }
            
          
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic)) // Add Searchable Modifier
            .onReceive(
                NotificationCenter.default.publisher(for: Notifications.openWorldNotification)
            ) { notification in
                guard let userInfo = notification.userInfo,
                      let worldName = userInfo["worldName"] as? String else { return }
                
                Task {
                      // Load saved worlds if necessary
                      await withCheckedContinuation { continuation in
                          worldManager.loadSavedWorlds {
                              continuation.resume()
                          }
                      }

                      // Assign the matching world
                      if let matchingWorld = worldManager.savedWorlds.first(where: { $0.name.lowercased() == worldName.lowercased() }) {
                          await MainActor.run {
                              let drop = Drop(title: "Loading \(matchingWorld.name)")
                              Drops.show(drop)
                            //  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                  
                                  selectedWorld = matchingWorld
                              //}
                          }
                      }
                  }
                
            }
            .onReceive(
                NotificationCenter.default.publisher(for: Notifications.createWorldNotification)
            ) { notification in
                guard let userInfo = notification.userInfo,
                      let worldName = userInfo["worldName"] as? String else { return }
                
                if worldName != "" {
                 //   DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        
                        selectedWorld = WorldModel(name: worldName)
                   // }
                }
                
            }
            .onReceive(
                       NotificationCenter.default.publisher(for: Notifications.incomingShareMapReady),
                       perform: { _ in
                           selectedWorld = WorldModel(name: WorldManager.shared.sharedWorldName ?? "")
                       }
                   )
            .onReceive(
                NotificationCenter.default.publisher(for: Notifications.findItemNotification)
            ) { notification in
                Task {
                    guard let userInfo = notification.userInfo,
                          let itemName = userInfo["itemName"] as? String else { return }
                    let providedWorldName = userInfo["worldName"] as? String ?? ""

                    // Option 1: Use the provided world name directly if it exists
                    if !providedWorldName.isEmpty,
                       let matchingWorld = worldManager.savedWorlds.first(where: { $0.name == providedWorldName }) {
                        findingAnchorName = itemName
                        worldManager.isShowingAll = false
                        isFindingAnchor = true
                        // Optionally, show a drop or perform any other UI feedback
                        await MainActor.run {
                            // Set findingAnchorName to the original anchor name with emoji
                           
                            let drop = Drop(title: "Anchor \(itemName) found in \(providedWorldName)")
                            Drops.show(drop)
                            selectedWorld = matchingWorld
                        }
                    } else {
                        // Option 2: Fallback to the logic that searches for an anchor if the world name isn’t provided
                        // Load anchors for all worlds if not already loaded
                        for world in worldManager.savedWorlds where anchorsByWorld[world.name] == nil {
                            await worldManager.getAnchorNames(for: world.name) { fetchedAnchors in
                                anchorsByWorld[world.name] = fetchedAnchors
                            }
                        }
                        
                        // Normalize names by removing emojis for comparison
                        func removeEmojis(from string: String) -> String {
                            return string.filter { !$0.isEmoji }
                        }
                        
                        if let (worldName, originalAnchorName) = anchorsByWorld.compactMap({ worldEntry -> (String, String)? in
                            let worldName = worldEntry.key
                            if let matchingAnchor = worldEntry.value.first(where: { removeEmojis(from: $0)
                                .localizedCaseInsensitiveContains(removeEmojis(from: itemName)) }) {
                                return (worldName, matchingAnchor)
                            }
                            return nil
                        }).first {
                            // Set findingAnchorName to the original anchor name with emoji
                            findingAnchorName = originalAnchorName
                            worldManager.isShowingAll = false
                            isFindingAnchor = true
                            await MainActor.run {
                                let drop = Drop(title: "Anchor \(originalAnchorName) found in \(worldName)")
                                Drops.show(drop)
                                if let matchingWorld = worldManager.savedWorlds.first(where: { $0.name == worldName }) {
                                    selectedWorld = matchingWorld
                                }
                            }
                        } else {
                            await MainActor.run {
                                let drop = Drop(title: "Anchor \(itemName) not found")
                                Drops.show(drop)
                            }
                        }
                    }
                }
            }

            .navigationTitle("it's here.")
            .toolbar {
                Menu {
                    Button("Name", systemImage: "textformat.size.larger") {
                                            sortingOption = .name
                                        }
                    .tint(colorScheme == .dark ? .white : .black)
                    Button("Date", systemImage: "calendar") {
                                            sortingOption = .lastModified
                                        }
                    .tint(colorScheme == .dark ? .white : .black)
                                    } label: {
                                        Label("Sort", systemImage: "arrow.up.arrow.down")
                                    }
                                    .tint(colorScheme == .dark ? .white : .black)
                
                Button {
                    isAddingNewRoom.toggle()
                    HapticManager.shared.impact(style: .medium)

                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
                
//                Button {
//                    isTestingAudio.toggle()
//                    HapticManager.shared.impact(style: .medium)
//
//                } label: {
//                    Image(systemName: "ladybug.fill")
//                        .font(.title2)
//                        .foregroundStyle(colorScheme == .dark ? .white : .black)
//                }
            }
            .sheet(item: $selectedWorld, onDismiss: {
                
                worldManager.loadSavedWorlds {
                    
                }
                
                if let anchorsToUpdate = updateRoomName {
                    worldManager.getAnchorNames(for: anchorsToUpdate) { fetchedAnchors in
                        DispatchQueue.main.async {
                            anchorsByWorld[anchorsToUpdate] = fetchedAnchors
                        }
                    }
                }
            }) { world in
                ContentView(
                    currentRoomName: world.name,
                    directLoading: true,
                    findAnchor: $findingAnchorName,
                    isShowingFocusedAnchor: $showFocusedAnchor
                )
                .interactiveDismissDisabled()

            }
            .sheet(isPresented: $isAddingNewRoom, onDismiss: {
                if roomName != "" {
                       // Start with the entered room name.
                       var newRoomName = roomName
                       var counter = 1
                       
                       // Check if the room name already exists (case-insensitive).
                       while worldManager.savedWorlds.contains(where: { $0.name.lowercased() == newRoomName.lowercased() }) {
                           // Append a counter to the original name to create a new candidate.
                           newRoomName = "\(roomName)\(counter)"
                           counter += 1
                       }
                       
                       // Create a new world with the unique name.
                       selectedWorld = WorldModel(name: newRoomName)
                   }
            }) {
                
//                    RoomScanGuideView()
//                } else {
                AddNewRoom(roomName: $roomName)
                        .presentationDetents([.fraction(0.4)])
                        .interactiveDismissDisabled()

              //  }
            }
            .sheet(isPresented: $isTestingAudio, content: {
                SensoryFeedbackView()
            })
            
//            .sheet(isPresented: $isShowingAnchors, onDismiss: {
//                if findingAnchorName != "" {
//                    
//                    
//                    worldManager.isShowingAll = false
//                    isFindingAnchor = true
//                    
//                    if let world = worldManager.savedWorlds.first(where: { $0.name == currentName }) {
//                        selectedWorld = world
//                    }
//                }
//               
//            }) {
//                AnchorsListView(worldManager: worldManager, worldName: $currentName, findingAnchorName: $findingAnchorName)
//            }
            .onChange(of: worldManager.reload) {
                print("reloaded")
            }
            .navigationDestination(isPresented: $isShowingAnchors) {
                  AnchorsListView(
                      worldManager: worldManager,
                      worldName: $currentName,
                      findingAnchorName: $findingAnchorName,
                      isOpeningFromAnchorListView: $isOpeningFromAnchorListView
                  )
                  .navigationTransition(.zoom(sourceID: "zoom-\(currentName)", in: animationNamespace))

                  .onDisappear {
                      if findingAnchorName != "" {
                          worldManager.isShowingAll = false
                          isFindingAnchor = true
                          if let world = worldManager.savedWorlds.first(where: { $0.name == currentName }) {
                              selectedWorld = world
                          }
                      }
                      
                      if isOpeningFromAnchorListView {
                          if let world = worldManager.savedWorlds.first(where: { $0.name == currentName }) {
                              worldManager.isShowingAll = true
                              selectedWorld = world
                              
                              isOpeningFromAnchorListView = false
                          }
                      }
                      currentName = ""
                  }
              }
            
         
        }
    }
    
    
}

import UIKit


func getDominantColor(for emoji: String) -> UIColor {
    let size = CGSize(width: 50, height: 50)
    let label = UILabel(frame: CGRect(origin: .zero, size: size))
    label.text = emoji
    label.font = UIFont.systemFont(ofSize: 50)
    label.textAlignment = .center
    
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    label.layer.render(in: UIGraphicsGetCurrentContext()!)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    guard let cgImage = image?.cgImage else { return .gray }
    let ciImage = CIImage(cgImage: cgImage)
    
    let filter = CIFilter(name: "CIAreaAverage")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")
    
    guard let outputImage = filter.outputImage else { return .gray }
    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext()
    context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
    
    return UIColor(red: CGFloat(bitmap[0]) / 255.0,
                   green: CGFloat(bitmap[1]) / 255.0,
                   blue: CGFloat(bitmap[2]) / 255.0,
                   alpha: CGFloat(bitmap[3]) / 255.0)
}
