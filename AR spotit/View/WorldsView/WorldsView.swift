import SwiftUI
import Drawer
import CloudKit
import Drops
import AppIntents
import CoreSpotlight
import MobileCoreServices
import TipKit
struct WorldsView: View {
    // MARK: - State Variables
    @StateObject var worldManager = WorldManager.shared
    @State private var selectedWorld: WorldModel? // For fullScreen navigation to ContentView
    @State private var anchorsByWorld: [String: [String]] = [:]
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    @State private var isAddingNewRoom = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isFindingAnchor = false
    @State private var findingAnchorName: String = ""
    @State private var showFocusedAnchor: Bool = false
    @State private var isTestingAudio = false
    @State private var searchText = ""
    @ObservedObject var appState = AppState.shared
    @State private var roomName: String = ""
    @State private var updateRoomName: String?
    @State private var isShowingAnchors: Bool = false
    @Namespace private var animationNamespace
    @State private var isShowingQR = false
    @State private var showPinPopover = false
    @State private var selectedPin: String = ""
    @State private var isShowingPIN = false
    @State private var isChecking = false
    @State private var isCollab = false
    @State private var newAnchors = 0
    @State private var isDeleting = false
    @State private var isRenaming = false
    @State private var showCollaboratedOnly: Bool = false
    @State private var isOpeningFromAnchorListView: Bool = false
    enum SortingField: String, CaseIterable, Identifiable {
        case name, date
        var id: String { self.rawValue }
    }
    @State private var hasLoadedWorlds = false
    @State private var isOpeningAnchorsSheet = false
    @State private var showCheckmark = false
    let newRoomTip = NewRoomTip()
    let worldsViewTip = WorldViewTip()
let shareWorldsTip = ShareWorldsTip()
    @AppStorage("sortingField") private var sortingFieldRawValue: String = SortingField.name.rawValue
    @AppStorage("sortingAscending") private var sortingAscending: Bool = true
    @AppStorage("isShowedScanningGuide") private var isShowedScanningGuide: Bool = false
    @AppStorage("isShowedWelcomeGuide") private var isShowedWelcomeGuide: Bool = false
@State private var isShowingWelcomeGuide: Bool = false
@State private var isShowingScanningGuide: Bool = false
    private var sortingField: SortingField {
        get { SortingField(rawValue: sortingFieldRawValue) ?? .name }
        set { sortingFieldRawValue = newValue.rawValue }
    }
    
    // MARK: - Computed Properties
    var filteredWorlds: [WorldModel] {
        let sortedWorlds: [WorldModel]
        if sortingField == .name {
            sortedWorlds = worldManager.savedWorlds.sorted {
                sortingAscending ?
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending :
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        } else {
            sortedWorlds = worldManager.savedWorlds.sorted {
                sortingAscending ?
                    $0.lastModified < $1.lastModified :
                    $0.lastModified > $1.lastModified
            }
        }
        let filtered = showCollaboratedOnly ? sortedWorlds.filter { $0.isCollaborative } : sortedWorlds
        
        if searchText.isEmpty { return filtered }
        return filtered.filter { world in
            world.name.localizedCaseInsensitiveContains(searchText) ||
            (anchorsByWorld[world.name]?.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ?? false)
        }
    }
    
    func filteredAnchors(for worldName: String) -> [String] {
        if searchText.isEmpty { return anchorsByWorld[worldName] ?? [] }
        if worldName.localizedCaseInsensitiveContains(searchText) { return anchorsByWorld[worldName] ?? [] }
        return (anchorsByWorld[worldName]?.filter { $0.localizedCaseInsensitiveContains(searchText) }) ?? []
    }
    
    // MARK: - Initializer
    init() {
        var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        titleFont = UIFont(
            descriptor: titleFont.fontDescriptor.withDesign(.rounded)?
                .withSymbolicTraits(.traitBold) ?? titleFont.fontDescriptor,
            size: titleFont.pointSize
        )
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
    }
    
    // New state variables to track which world to act on:
    @State private var worldForRename: WorldModel? = nil
    @State private var worldForQR: WorldModel? = nil
    @State private var worldForPin: WorldModel? = nil
    @State private var worldForDelete: WorldModel? = nil
    @State private var worldForAnchors: WorldModel? = nil
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        if filteredWorlds.isEmpty && searchText.isEmpty {
                            VStack {
                                Spacer()
                                ContentUnavailableView {
                                    Label("No Area saved yet!", systemImage: "viewfinder")
                                        .font(.system(.title2, design: .rounded))
                                } description: {
                                    Text("Start adding an area by tapping the plus \(Image(systemName: "plus.circle")) button.")
                                        .font(.system(.headline, design: .rounded))

                                }
                                Spacer()
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.7)
                        }
                        
                        if !searchText.isEmpty && filteredWorlds.isEmpty {
                            VStack {
                                Spacer()
                                ContentUnavailableView {
                                    Label("No Results for '\(searchText)'", systemImage: "magnifyingglass")
                                        .font(.system(.title2, design: .rounded))
                                } description: {
                                    Text("Check spelling or try new search.")
                                        .font(.system(.headline, design: .rounded))

                                }
                                Spacer()
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.7)
                        }
                        
                        
                        if !filteredWorlds.isEmpty {
                            TipView(worldsViewTip)
                                .padding(.horizontal)
                                .tint(colorScheme == .dark ? .white : .black)
                        }
                        
                        ForEach(filteredWorlds) { world in
                            VStack(alignment: .leading) {
                                WorldCellView(
                                    world: world,
                                    anchors: anchorsByWorld[world.name] ?? [],
                                    searchText: searchText,
                                    colorScheme: colorScheme,
                                    animationNamespace: animationNamespace,
                                    onTap: {
                                        
                                        worldsViewTip.invalidate(reason: .actionPerformed)

                                        HapticManager.shared.impact(style: .medium)
                                        worldForAnchors = world
                                        isShowingAnchors = true
                                    },
                                    onARKitTap: {
                                        updateRoomName = world.name
                                        worldManager.isShowingAll = true
                                        selectedWorld = world
                                    },
                                    onRename: {
                                        HapticManager.shared.impact(style: .medium)
                                        DispatchQueue.main.async { worldForRename = world }
                                        withAnimation { isRenaming = true }
                                    },
                                    onShare: {
                                        worldManager.shareWorld(currentRoomName: world.name)
                                        HapticManager.shared.impact(style: .medium)
                                    },
                                    onShareQR: {
                                        DispatchQueue.main.async { worldForQR = world }
                                        isShowingQR = true
                                    },
                                    onShowPIN: {
                                        DispatchQueue.main.async { worldForPin = world }
                                        selectedPin = world.pin ?? ""
                                        showPinPopover = true
                                    },
                                    onDelete: {
                                        DispatchQueue.main.async { worldForDelete = world }
                                        isDeleting = true
                                    },
                                    onAnchorTap: { anchorName in
                                        worldManager.isShowingAll = false
                                        isFindingAnchor = true
                                        findingAnchorName = anchorName
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            selectedWorld = world
                                        }
                                    },
                                    filteredAnchors: filteredAnchors(for: world.name)
                                )
                                .onAppear {
                                    if anchorsByWorld[world.name] == nil ||
                                        anchorsByWorld[world.name]?.isEmpty == true {
                                        worldManager.getAnchorNames(for: world.name) { fetchedAnchors in
                                            DispatchQueue.main.async {
                                                anchorsByWorld[world.name] = fetchedAnchors
                                                
                                            
                                                let tupleAnchors = fetchedAnchors
                                                    .filter { $0 != "guide" }
                                                    .map { (anchorName: $0, worldName: world.name) }
                                                worldManager.indexItems(anchors: tupleAnchors)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        
                        
                        if !hasLoadedWorlds {
                            hasLoadedWorlds = true
                            worldManager.loadSavedWorlds {
                                // Handle completion if needed
                            }
                        }
                    }
                    .onChange(of: AppState.shared.isWorldUpdated) {
                        worldManager.loadSavedWorlds {}
                    }
                    .padding(.top)
                }
                .padding(.bottom, !worldManager.sharedLinks.isEmpty ? 70 : 0)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
                .tint(colorScheme == .dark ? .white : .black)
                .onReceive(NotificationCenter.default.publisher(for: Notifications.openWorldNotification)) { notification in
                    guard let userInfo = notification.userInfo,
                          let worldName = userInfo["worldName"] as? String else { return }
                    Task {
                        await withCheckedContinuation { continuation in
                            worldManager.loadSavedWorlds { continuation.resume() }
                        }
                        if let matchingWorld = worldManager.savedWorlds.first(where: {
                            $0.name.lowercased() == worldName.lowercased()
                        }) {
                            await MainActor.run {
                                let drop = Drop(title: "Loading \(matchingWorld.name)")
                                Drops.show(drop)
                                selectedWorld = matchingWorld
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notifications.createWorldNotification)) { notification in
                    guard let userInfo = notification.userInfo,
                          let worldName = userInfo["worldName"] as? String else { return }
                    if !worldName.isEmpty {
                        selectedWorld = WorldModel(name: worldName)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notifications.incomingShareMapReady)) { _ in
                    if AppState.shared.isViewOnly {
                        isOpeningAnchorsSheet = true

                    } else {
                        selectedWorld = WorldModel(name: WorldManager.shared.sharedWorldName ?? "")
                    }
                }
                .onChange(of: AppState.shared.isiCloudSyncActive) { newValue in
                    if !newValue {
                        withAnimation(.easeIn(duration: 0.3)) {
                            showCheckmark = true
                        }
                        // After 1 second, fade it out:
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showCheckmark = false
                            }
                        }
                    }
                }
                .sheet(isPresented: $isOpeningAnchorsSheet) {
                    ExploreSharedView(arWorldMap: WorldManager.shared.sharedARWorldMap) { anchorName in
                        
                        if anchorName != "" {
                            findingAnchorName = anchorName
                            selectedWorld = WorldModel(name: WorldManager.shared.sharedWorldName ?? "")

                        } else {
                            selectedWorld = WorldModel(name: WorldManager.shared.sharedWorldName ?? "")
                        }
                        isOpeningAnchorsSheet = false

                    }
                   
                    
                }
                .sheet(isPresented: $isShowingScanningGuide) {
                    ARViewGuideView() {
                        isAddingNewRoom.toggle()
                        HapticManager.shared.impact(style: .medium)
                        newRoomTip.invalidate(reason: .actionPerformed)
                        isShowedScanningGuide = true
                    }
                }
                .fullScreenCover(isPresented: $isShowingWelcomeGuide) {
                    GeometryReader { geometry in
                        WelcomeView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
              
                .onReceive(NotificationCenter.default.publisher(for: Notifications.findItemNotification)) { notification in
                    Task {
                        guard let userInfo = notification.userInfo,
                              let itemName = userInfo["itemName"] as? String else { return }
                        let providedWorldName = userInfo["worldName"] as? String ?? ""
                        if !providedWorldName.isEmpty,
                           let matchingWorld = worldManager.savedWorlds.first(where: { $0.name == providedWorldName }) {
                            findingAnchorName = itemName
                            worldManager.isShowingAll = false
                            isFindingAnchor = true
                            await MainActor.run {
                                let drop = Drop(title: "Anchor \(itemName) found in \(providedWorldName)")
                                Drops.show(drop)
                                selectedWorld = matchingWorld
                            }
                        } else {
                            for world in worldManager.savedWorlds where anchorsByWorld[world.name] == nil {
                                worldManager.getAnchorNames(for: world.name) { fetchedAnchors in
                                    anchorsByWorld[world.name] = fetchedAnchors
                                }
                            }
                            func removeEmojis(from string: String) -> String {
                                return string.filter { !$0.isEmoji }
                            }
                            if let (worldName, originalAnchorName) = anchorsByWorld.compactMap({ worldEntry -> (String, String)? in
                                let worldName = worldEntry.key
                                if let matchingAnchor = worldEntry.value.first(where: {
                                    removeEmojis(from: $0).localizedCaseInsensitiveContains(removeEmojis(from: itemName))
                                }) {
                                    return (worldName, matchingAnchor)
                                }
                                return nil
                            }).first {
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
                    
                    ToolbarItemGroup(placement: .topBarLeading) {
                        if AppState.shared.isiCloudSyncActive {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                .foregroundStyle(.blue)
                                .symbolEffect(.rotate)
                        } else if showCheckmark {
                            Image(systemName: "checkmark.icloud")
                                .transition(.opacity)
                                .symbolEffect(.bounce)

                        }
                        
                        
                        Button {
                            isShowingWelcomeGuide = true
                        } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)

                        }
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button {
                               showCollaboratedOnly.toggle()
                               HapticManager.shared.impact(style: .medium)
                            } label: {
                               HStack {
                                   Text(showCollaboratedOnly ? "Show All" : "Show Collaborated Only")
                                   Spacer()
                                   Image(systemName: showCollaboratedOnly ? "square.split.1x2.fill" : "person.2")
                               }
                            }
                            Picker("Sort By", selection: Binding<SortingField>(
                                get: {
                                    SortingField(rawValue: sortingFieldRawValue) ?? .name
                                },
                                set: { newValue in
                                    if SortingField(rawValue: sortingFieldRawValue) == newValue {
                                        sortingAscending.toggle()
                                    } else {
                                        sortingFieldRawValue = newValue.rawValue
                                        sortingAscending = true
                                    }
                                    HapticManager.shared.impact(style: .medium)
                                }
                            )) {
                                ForEach(SortingField.allCases) { field in
                                    HStack {
                                        Text(field.rawValue.capitalized)
                                        Spacer()
                                        if field == .name {
                                            Image(systemName: "textformat")
                                        } else if field == .date {
                                            Image(systemName: "calendar")
                                        }
                                    }
                                    .tag(field)
                                }
                            }
                            .pickerStyle(.menu)
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        .tint(colorScheme == .dark ? .white : .black)
                        
                        Button {
                            
                            if !isShowedScanningGuide {
                                isShowingScanningGuide = true
                            } else {
                                isAddingNewRoom.toggle()
                                HapticManager.shared.impact(style: .medium)
                                newRoomTip.invalidate(reason: .actionPerformed)
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        .popoverTip(newRoomTip)
                    }
                  
                }
                .fullScreenCover(item: $selectedWorld, onDismiss: {
                    worldManager.loadSavedWorlds {}
                    if let anchorsToUpdate = updateRoomName {
                        worldManager.getAnchorNames(for: anchorsToUpdate) { fetchedAnchors in
                            DispatchQueue.main.async {
                                anchorsByWorld[anchorsToUpdate] = fetchedAnchors
                            }
                        }
                    }
                }) { world in
                    AugmentedView(
                        currentRoomName: world.name,
                        directLoading: true,
                        findAnchor: $findingAnchorName,
                        isShowingFocusedAnchor: $showFocusedAnchor
                    )
                    .interactiveDismissDisabled()
                }
                .sheet(isPresented: $isAddingNewRoom, onDismiss: {
//                    if roomName != "" {
//                        var newRoomName = roomName
//                        var counter = 1
//                        while worldManager.savedWorlds.contains(where: { $0.name.lowercased() == newRoomName.lowercased() }) {
//                            newRoomName = "\(roomName)\(counter)"
//                            counter += 1
//                        }
//                        selectedWorld = WorldModel(name: newRoomName)
//                    }
                }) {
                    AddNewRoom(roomName: $roomName) {
                        if roomName != "" {
                            var newRoomName = roomName
                            var counter = 1
                            while worldManager.savedWorlds.contains(where: { $0.name.lowercased() == newRoomName.lowercased() }) {
                                newRoomName = "\(roomName)\(counter)"
                                counter += 1
                            }
                            selectedWorld = WorldModel(name: newRoomName)
                        }
                    }
                        .conditionalModifier(!UIDevice.isIpad) { view in
                            view.presentationDetents([.fraction(0.4)])
                        }
                     //   .interactiveDismissDisabled()
                }
                .sheet(isPresented: $isTestingAudio, content: {
                    SensoryFeedbackView()
                })
                .navigationDestination(isPresented: $isShowingAnchors) {
                    AnchorsListView(
                        worldManager: worldManager,
                        worldName: .constant(worldForAnchors?.name ?? ""),
                        findingAnchorName: $findingAnchorName,
                        isOpeningFromAnchorListView: $isOpeningFromAnchorListView
                    )
                    .navigationTransition(.zoom(sourceID: "zoom-\(worldForAnchors?.name ?? "")", in: animationNamespace))
                    .onDisappear {
                        if findingAnchorName != "" {
                            worldManager.isShowingAll = false
                            isFindingAnchor = true
                            if let world = worldManager.savedWorlds.first(where: { $0.name == worldForAnchors?.name }) {
                                selectedWorld = world
                            }
                        }
                        if isOpeningFromAnchorListView {
                            if let world = worldManager.savedWorlds.first(where: { $0.name == worldForAnchors?.name }) {
                                worldManager.isShowingAll = true
                                selectedWorld = world
                                isOpeningFromAnchorListView = false
                            }
                        }
                        worldForAnchors = nil
                    }
                }
                
                .sheet(item: $worldForQR) { qrWorld in
                    QRview(roomName: qrWorld.name)
                        .id(qrWorld.id)
                        .conditionalModifier(!UIDevice.isIpad) { view in
                            view.presentationDetents([.fraction(0.5)])
                        }
                }
                .sheet(item: $worldForRename) { renameWorld in
                    renameWorldView(
                        worldName: renameWorld.name,
                        worldManager: worldManager,
                        showWarning: renameWorld.isCollaborative,
                        newAnchors: newAnchors,
                        publicName: renameWorld.publicRecordName ?? ""
                    )
                    .id(renameWorld.id)
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents(renameWorld.isCollaborative ? [.fraction(0.5)] : [.fraction(0.4)])
                    }
                }
                .sheet(item: $worldForPin) { pinWorld in
                    PinView(
                        roomName: pinWorld.name,
                        pin: $selectedPin,
                        isChecking: true
                    )
                    .id(pinWorld.id)
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.5)])
                    }
                }
                .sheet(item: $worldForDelete) { deleteWorld in
                    DeleteConfirm(isCollab: deleteWorld.isCollaborative,
                                  roomName: deleteWorld.name) { name in
                        worldManager.deleteWorld(roomName: name, publicName: deleteWorld.publicRecordName ?? "") {
                            let drop = Drop(title: "\(deleteWorld.name) deleted!")
                            Drops.show(drop)
                            HapticManager.shared.notification(type: .success)
                            isDeleting = false
                        }
                    }
                    .id(deleteWorld.id)
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.5)])
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
               
                
                VStack {
                    Spacer()
                    if !worldManager.sharedLinks.isEmpty {
                        Drawer {
                            
                            ZStack {
                                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                                    .shadow(color: colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4), radius: 10)

                                VStack {
                                    RoundedRectangle(cornerRadius: 3.0)
                                        .foregroundColor(.gray)
                                        .frame(width: 30.0, height: 6.0)
                                        .padding()
                                        .popoverTip(shareWorldsTip)
                                        .tint(.black)

                                    
                                    HStack {
                                        Text("Shared With You")
                                            .font(.system(.title2, design: .rounded))
                                            .bold()
                                        
                                        Image(systemName: "shared.with.you")
                                            .font(.system(.title3, design: .rounded))
                                            .foregroundStyle(.blue)
                                            .bold()
                                            .symbolEffect(.pulse)
                                            .shadow(color: .blue.opacity(0.8), radius: 10)


                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(worldManager.sharedLinks) { sharedLink in
                                                
                                                HStack(alignment: .top) {
                                                    // Display the snapshot preview image (if available)
                                                    if let snapshotURL = sharedLink.snapshotURL,
                                                       let imageData = try? Data(contentsOf: snapshotURL),
                                                       let image = UIImage(data: imageData) {
                                                        Image(uiImage: image)
                                                            .resizable()
                                                            .frame(width: 50, height: 50)
                                                            .cornerRadius(8)
                                                            .conditionalModifier(colorScheme != .dark) { view in
                                                                view.colorInvert()
                                                            }
                                                            .shadow(color: colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2), radius: 5)
                                                    } else {
                                                        Image(systemName: "photo")
                                                            .resizable()
                                                            .frame(width: 80, height: 80)
                                                            .cornerRadius(8)
                                                    }
                                                    VStack(alignment: .leading) {
                                                        Text(sharedLink.roomName)
                                                            .font(.system(.headline, design: .rounded))
                                                            .lineLimit(1)
                                                        Text("By: \(sharedLink.ownerName)")
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                .padding(7)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    shareWorldsTip.invalidate(reason: .actionPerformed)

                                                    if let snapshotURL = sharedLink.snapshotURL {
                                                        if let imageData = try? Data(contentsOf: snapshotURL) {
                                                            if let image = UIImage(data: imageData) {
                                                                AppState.shared.sharedWorldImage = Image(uiImage: image)
                                                            }
                                                            
                                                        }

                                                        
                                                    }
                                                    
                                                    AppState.shared.ownerName = sharedLink.ownerName
                                                    AppState.shared.isOpeningSharedLink = true
                                                    worldManager.openSharedLink(sharedLink)
                                                   
                                                }
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        worldManager.deleteSharedLink(sharedLink)
                                                    } label: {
                                                        HStack {
                                                            Text("Delete")
                                                                .foregroundColor(.red)
                                                            Image(systemName: "trash.fill")
                                                                .foregroundStyle(.red)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.top)

                                    Spacer()
                                }
                            }
                        }
                        .rest(at: .constant([60, 150]))
                        .impact(.light)
                    }
                }
                
                
                if AppState.shared.isOpeningSharedLink {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                    VStack {
                        ProgressView {
                            Text("Preparing the map.")
                                .font(.system(.headline, design: .rounded))
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}






