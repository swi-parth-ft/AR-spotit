import SwiftUI
import CloudKit
import Drops
import AppIntents
import CoreSpotlight
import MobileCoreServices

struct WorldsView: View {
    // MARK: - State Variables
    @StateObject var worldManager = WorldManager()
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

    @AppStorage("sortingField") private var sortingFieldRawValue: String = SortingField.name.rawValue
    @AppStorage("sortingAscending") private var sortingAscending: Bool = true

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
                                }
                                Spacer()
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.7)
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
                                                let tupleAnchors = fetchedAnchors.map { (anchorName: $0, worldName: world.name) }
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
                    selectedWorld = WorldModel(name: WorldManager.shared.sharedWorldName ?? "")
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
                        isAddingNewRoom.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
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
                        var newRoomName = roomName
                        var counter = 1
                        while worldManager.savedWorlds.contains(where: { $0.name.lowercased() == newRoomName.lowercased() }) {
                            newRoomName = "\(roomName)\(counter)"
                            counter += 1
                        }
                        selectedWorld = WorldModel(name: newRoomName)
                    }
                }) {
                    AddNewRoom(roomName: $roomName)
                        .conditionalModifier(!UIDevice.isIpad) { view in
                            view.presentationDetents([.fraction(0.4)])
                        }
                        .interactiveDismissDisabled()
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
                
                // Sheets for various actions
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
                        view.presentationDetents([.fraction(0.4)])
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
            }
        }
    }
}






