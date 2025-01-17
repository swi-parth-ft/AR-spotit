import SwiftUI

struct WorldsView: View {
    
  
    
    @ObservedObject var worldManager = WorldManager()
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
    func extractEmoji(from string: String) -> String? {
        for char in string {
                if char.isEmoji {
                    return String(char)
                }
            }
            return nil
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(worldManager.savedWorlds) { world in
                        VStack(alignment: .leading, spacing: 10) {
                            // Room Title
                            HStack {
                              
                                    Text(world.name)
                                        .font(.system(.title2, design: .rounded))
                                        .bold()
                                
                                Spacer()
                                Button(action: {
                                    worldManager.isShowingAll = true
                                    selectedWorld = world // Set the selected world
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.title)
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                }
                                
                                Menu {
                                    Button {
                                        
                                        isRenaming.toggle()
                                    } label: {
                                        HStack {
                                            Text("Rename")
                                            Image(systemName: "character.cursor.ibeam")
                                                .font(.title)
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                        }
                                    }
                                    
                                    Button(role: .destructive) {
                                        worldManager.deleteWorld(roomName: world.name) {
                                            print("Deletion process completed.")
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
                                    Image(systemName: "pencil.and.scribble")
                                        .font(.title)
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                }
                                

                            }
                            .padding(.horizontal)

                            // Anchors Section
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVGrid(columns: columns, spacing: 10) {
                                    if let anchors = anchorsByWorld[world.name], !anchors.isEmpty {
                                        // Filter out "guide" anchors
                                        let nonGuideAnchors = anchors.filter { $0 != "guide" }
                                   
                                        
                                        // Show non-guide anchors
                                        ForEach(Array(nonGuideAnchors.enumerated()), id: \.0) { index, anchorName in
                                            VStack {
                                                    // Extract and display the emoji if present
                                                let emoji = extractEmoji(from: anchorName)
                                                    Text(emoji ?? "📍")
                                                    .font(.system(size: 50))
                                                    // Display the anchor name without the emoji
                                                let cleanAnchorName = anchorName.filter { !$0.isEmoji }
                                                    Text(cleanAnchorName)
                                                    .font(.system(.headline, design: .rounded))
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
                .padding(.top)
                .sheet(isPresented: $isRenaming) {
                    
                    renameWorldView(worldName: $currentName, worldManager: worldManager)
                        .presentationDetents([.fraction(0.4)])

                        
                }
            }
         
            .navigationTitle("My Things")
            .toolbar {
                Button {
                    isAddingNewRoom.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }
            .sheet(item: $selectedWorld) { world in
                ContentView(
                    currentRoomName: world.name,
                    directLoading: true,
                    findAnchor: $findingAnchorName,
                    isShowingFocusedAnchor: $showFocusedAnchor
                )
                .interactiveDismissDisabled()

            }
            .sheet(isPresented: $isAddingNewRoom) {
                
//                    RoomScanGuideView()
//                } else {
                    AddNewRoom()
                        .presentationDetents([.fraction(0.4)])
              //  }
            }
            .onChange(of: worldManager.reload) {
                print("reloaded")
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
