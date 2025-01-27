import SwiftUI
import Drops

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
    
    init() {
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
                                    // Fetch anchors for this specific world
                                    if anchorsByWorld[world.name] == nil || anchorsByWorld[world.name]?.isEmpty == true {
                                        worldManager.getAnchorNames(for: world.name) { fetchedAnchors in
                                            DispatchQueue.main.async {
                                                anchorsByWorld[world.name] = fetchedAnchors
                                            }
                                        }
                                    }
                                }
                            }
                        }
              
                    }
                }
                .onAppear {
                    if currentName == "" {
                        worldManager.loadSavedWorlds {
                            
//                                NotificationCenter.default.addObserver(forName: Notification.Name("OpenWorldNotification"), object: nil, queue: .main) { notification in
//                                    if let userInfo = notification.userInfo,
//                                       let worldName = userInfo["worldName"] as? String {
//                                        if let world = worldManager.savedWorlds.first(where: { $0.name == worldName }) {
//                                            selectedWorld = world
//                                        }
//                                    }
//                                
//                            }
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
                NotificationCenter.default.publisher(for: Notification.Name("OpenWorldNotification"))
            ) { notification in
                guard let userInfo = notification.userInfo,
                      let worldName = userInfo["worldName"] as? String else { return }
                
                Task {
                    // Use async/await to handle the loading process deterministically
                    await withCheckedContinuation { continuation in
                        worldManager.loadSavedWorlds {
                            continuation.resume() // Signal that loading is complete
                        }
                    }

                    // Now find the matching world
                    if let matchingWorld = worldManager.savedWorlds.first(where: { $0.name == worldName }) {
                        // Safely update `selectedWorld` on the main thread
                        await MainActor.run {
                            selectedWorld = matchingWorld
                        }
                    }
                }
                
//                // Make sure we have our local list loaded first
//                worldManager.loadSavedWorlds {
//                    // Now we can safely find the matching world
//                    if let matchingWorld = worldManager.savedWorlds.first(where: { $0.name == worldName }) {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                            
//                            selectedWorld = matchingWorld
//                        }
//                    }
//                }
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
                    selectedWorld = WorldModel(name: roomName)
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
