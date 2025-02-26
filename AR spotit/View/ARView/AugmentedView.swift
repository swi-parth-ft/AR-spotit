import SwiftUI
import CloudKit
import AnimateText
import CoreHaptics
import ARKit
import AVFoundation
import Drops



struct AugmentedView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var showAnchorList = false
    @State private var newRoom = ""
    var sceneView = ARSCNView()
    @State private var audioEngine = AVAudioEngine()
    @State private var audioPlayer = AVAudioPlayerNode()
    
    @State private var currentInstruction: String = "Start scanning the Front Wall."
    @State private var progress: Float = 0.0
    @State private var arrowAngleY: Float = 0.0
    var directLoading: Bool
    @State private var hasLoadedWorldMap = false
    @Binding var findAnchor: String
    @State private var animate = false
    @State private var isFlashlightOn = false
    @Binding var isShowingFocusedAnchor: Bool
    @State private var isAddingNewAnchor: Bool = false
    
    @State private var shouldPlay = false
    @State private var isEditingAnchor: Bool = false
    @State private var nameOfAnchorToEdit: String = ""
    
    @State private var engine: CHHapticEngine?
    @State private var animateButton = false
    @GestureState private var isPressed = false // For press detection
    
    @State private var angle: Double = 0.0 // Arrow rotation angle
    @State private var distance: Double = 0.0
    @State private var itshere = ""
    @State private var animatedAngle = ""
    @State private var isOpeningSharedWorld = false
    @State private var showAnchorListSheet = false
    @State private var isCollab = false
    @State private var recordName: String = ""
    @Namespace private var arrowNamespace
    @Namespace private var itshereNamespace

    @State private var newAnchorsCount: Int = 0
    @State private var coordinatorRef: ARViewContainer.Coordinator? = nil
    @State private var isCameraPointingDown: Bool = false
    @State private var hasPlayedItshere = false
    @State private var errorEditingAnchor: Bool = false
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    ARViewContainer(
                        sceneView: sceneView,
                        anchorName: $currentAnchorName,
                        worldManager: worldManager,
                        findAnchor: $findAnchor,
                        showFocusedAnchor: $isShowingFocusedAnchor,
                        shouldPlay: $shouldPlay,
                        isEditingAnchor: $isEditingAnchor,
                        nameOfAnchorToEdit: $nameOfAnchorToEdit,
                        angle: $angle,
                        distanceForUI: $distance,
                        roomName: currentRoomName,
                        isCollab: $isCollab,
                        recordName: $recordName,
                        isCameraPointingDown: $isCameraPointingDown,
                        errorEditingAnchor: $errorEditingAnchor, onCoordinatorMade: { coord in
                            coordinatorRef = coord
                        }
                    )
                    .onAppear {
                        if findAnchor != "" {
                            worldManager.isShowingAll = false
                        }
                    }
                    .onDisappear {
                        shouldPlay = false
                        if audioPlayer.isPlaying {
                            audioPlayer.stop()
                        }
                        if audioEngine.isRunning {
                            audioEngine.stop()
                            audioEngine.reset()
                        }
                        sceneView.session.pause()
                        sceneView.delegate = nil
                        sceneView.session.delegate = nil
                    }
                    .edgesIgnoringSafeArea(.all)
                    
                    // Overlay when camera is pointing down and relocalization is complete
                    cameraDownOverlay
                    
                    // Bottom overlay when relocalization is complete
                    relocalizationBottomOverlay
                    
                    // Either show the guide or the scanning overlay
                    if !worldManager.isShowingARGuide || !worldManager.isRelocalizationComplete {
                        guideOverlay
                    } else {
                        scanningOverlay
                    }
                }
            }
            .onAppear(perform: onViewAppear)
            .onChange(of: distance) { newDistance in
                if newDistance < 0.3 && !hasPlayedItshere {
                    hasPlayedItshere = true
                    playItshereMP3(sound: "itshere")
                } else if newDistance > 0.3 {
                    hasPlayedItshere = false
                }
            }
            .onChange(of: worldManager.scannedZones) { _ in
                updateScanningProgress()
            }
            .onChange(of: worldManager.isShowingAll) {
                DispatchQueue.main.async {
                    if let coref = coordinatorRef {
                        coref.updateNodeVisibility(in: sceneView)
                    } else {
                        print("coordinatorRef is nil")
                    }
                }
            }
            .onReceive(timer) { _ in
                print("Timer fired – findAnchor: \(findAnchor), angle: \(angle)")
                if !findAnchor.isEmpty && shouldPlay {
                    playItshereMP3(sound: "opened", withAngle: -angle)
                }
            }
            .onChange(of: worldManager.isRelocalizationComplete) {
                if worldManager.isRelocalizationComplete {
                    playItshereMP3(sound: "opened")
                }
            }
            .sheet(isPresented: $showAnchorListSheet) {
                AnchorListSheet(sceneView: sceneView, onSelectAnchor: { selectedAnchorName in
                    findAnchor = selectedAnchorName
                    print(findAnchor)
                    worldManager.isShowingAll = false
                    showAnchorListSheet = false
                })
                .conditionalModifier(!UIDevice.isIpad) { view in
                    view.presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $isAddingNewAnchor) {
                AddAnchorView(anchorName: $currentAnchorName, worldManager: worldManager)
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.6)])
                    }
            }
            .sheet(isPresented: $isEditingAnchor) {
                EditAnchorView(
                    anchorName: $nameOfAnchorToEdit,
                    onDelete: { anchorName in
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.deleteAnchor(anchorName: anchorName, recId: recordName)
                                let drop = Drop(title: "\(anchorName) deleted")
                                Drops.show(drop)
                                print("Anchor '\(anchorName)' deleted.")
                            } else {
                                print("Coordinator is nil — even with stable ref (unexpected).")
                            }
                        }
                        isEditingAnchor = false
                    },
                    onMove: { anchorName in
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.prepareToMoveAnchor(anchorName: anchorName, recId: recordName)
                            }
                        }
                        isEditingAnchor = false
                    },
                    onRename: { oldName, newName in
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.renameAnchor(oldName: oldName, newName: newName, recId: recordName)
                            }
                        }
                        isEditingAnchor = false
                    }
                )
                .conditionalModifier(!UIDevice.isIpad) { view in
                    view.presentationDetents([.fraction(0.6)])
                }
            }
            .sheet(isPresented: $errorEditingAnchor) {
                CanNotModifyAnchorView(anchorName: $nameOfAnchorToEdit)
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.6)])
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if AppState.shared.isiCloudShare {
                            AppState.shared.isiCloudShare = false
                        }
                        if AppState.shared.isViewOnly {
                            AppState.shared.isViewOnly = false
                        }
                        worldManager.isWorldLoaded = false
                        shouldPlay = false
                        findAnchor = ""
                        coordinatorRef?.stopAudio()
                        coordinatorRef?.pauseSession()
                        sceneView.session.pause()
                        HapticManager.shared.impact(style: .medium)
                        if !isOpeningSharedWorld {
                            coordinatorRef?.pauseSession()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Text(currentRoomName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                        if isCollab || AppState.shared.isiCloudShare {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                                .symbolEffect(.breathe)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Computed Subviews

extension AugmentedView {
    
    /// Overlay for when the camera is pointing down and relocalization is complete.
    var cameraDownOverlay: some View {
    Group {
        if isCameraPointingDown && worldManager.isRelocalizationComplete {
            ZStack {
                VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                if findAnchor != "" {
                    VStack {
                        VStack {
                            ZStack {
                                if distance < 0.5 {
                                    if distance > 0.35 {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 240, weight: .bold))
                                            .foregroundStyle(.orange.opacity(0.4))
                                            .shadow(color: Color.orange.opacity(0.1), radius: 10)
                                            .symbolEffect(.pulse)
                                    }
                                    if distance > 0.2 {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 240, weight: .bold))
                                            .foregroundStyle(.orange.opacity(0.7))
                                            .shadow(color: Color.orange.opacity(0.3), radius: 10)
                                            .symbolEffect(.breathe)
                                    }
                                }
                                Circle()
                                    .fill(.orange)
                                    .frame(width: distance < 0.5 ? 200 : 40)
                                    .shadow(color: Color.orange.opacity(0.5), radius: 10)
                            }
                            .offset(y: -50)
                            if distance > 0.5 {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 240, weight: .bold))
                                    .foregroundStyle(.white)
                                    .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
                                    .shadow(color: Color.white.opacity(0.5), radius: 10)
                            }
                        }
                        .rotationEffect(Angle(degrees: -angle))
                        .animation(.easeInOut(duration: 0.5), value: angle)
                    }
                }
            }
        }
    }
}
    
    /// Bottom overlay when relocalization is complete.
    var relocalizationBottomOverlay: some View {
    Group {
        if worldManager.isRelocalizationComplete {
            VStack {
                Spacer()
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                    .frame(width: UIScreen.main.bounds.width, height: 200)
                    .cornerRadius(22)
            }
            .ignoresSafeArea()
        }
    }
}
    
    /// Guide overlay shown when AR guide isn’t active or relocalization isn’t complete.
    var guideOverlay: some View {
    ZStack {
        CircleView(
            text: !findAnchor.isEmpty ? findAnchor.filter { !$0.isEmoji } : currentRoomName,
            emoji: extractEmoji(from: findAnchor) ?? "🔍"
        )
        .padding(.top)
        .frame(width: 800, height: 800)
        VStack {
            Spacer()
            Button {
                toggleFlashlight()
                HapticManager.shared.impact(style: .medium)
                animateButton = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateButton = false
                }
            } label: {
                Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.black)
                    .frame(width: 65, height: 65)
                    .background(Color.white)
                    .cornerRadius(40)
                    .shadow(color: Color.white.opacity(0.5), radius: 10)
                    .scaleEffect(isPressed ? 1.3 : (animateButton ? 1.4 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isPressed)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: animateButton)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.25)
                    .updating($isPressed) { currentState, gestureState, _ in
                        gestureState = currentState
                    }
            )
            .sensoryFeedback(.impact(weight: .heavy, intensity: 5), trigger: isFlashlightOn)
            .padding(30)
        }
        .padding()
    }
}
    
    /// Scanning overlay shown when AR guide is active and relocalization is complete.
    var scanningOverlay: some View {
    VStack {
        if !directLoading {
            ProgressBar(progress: progress)
                .padding()
            Text(currentInstruction)
                .font(.headline)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .padding(.bottom, 20)
        }
        if findAnchor != "" {
            HStack {
                VStack(alignment: .leading) {
                    Text("FINDING")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.gray)
                        .bold()
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                    Text("\(findAnchor)")
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundStyle(.white)
                        .bold()
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                    HStack {
                        if distance < 0.9 {
                            AnimateText<ATOffsetEffect>($itshere)
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(.white)
                                .bold()
                                .matchedGeometryEffect(id: "itshere", in: itshereNamespace)
                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                .onAppear {
                                    itshere = "it's here."
                                    animatedAngle = ""
                                }
                        } else {
                            Text("\(String(format: "%.2f", distance))m")
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(Color.white)
                                .bold()
                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                .contentTransition(.numericText(value: distance))
                                .onAppear {
                                    itshere = ""
                                }
                            AnimateText<ATOffsetEffect>($animatedAngle)
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(.white)
                                .bold()
                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                .onChange(of: angle) { _ in
                                    animatedAngle = "\(Direction.classify(angle: angle))."
                                }
                        }
                    }
                }
                Spacer()
            }
            .padding()
            
            HStack {
                if findAnchor != "" && !isCameraPointingDown {
                    if !worldManager.is3DArrowActive {
                        Image(systemName: "arrow.up")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.white)
                            .bold()
                            .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
                            .rotationEffect(.degrees(-angle))
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)))
                            .animation(.easeInOut(duration: 0.7), value: angle)
                            .shadow(color: Color.white.opacity(0.5), radius: 10)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, -20)
        }
        Spacer()
        VStack {
            HStack(spacing: 10) {
                if !AppState.shared.isViewOnly {
                    Button {
                        isAddingNewAnchor.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 65, height: 65)
                            Image(systemName: "plus")
                                .foregroundStyle(.black)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .shadow(color: Color.white.opacity(0.5), radius: 10)
                }
                Button {
                    toggleFlashlight()
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isFlashlightOn ? Color.white : Color.black.opacity(0.5))
                            .frame(width: 65, height: 65)
                        Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundStyle(isFlashlightOn ? .black : .white)
                            .font(.title2)
                            .bold()
                    }
                }
                .shadow(color: isFlashlightOn ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                if isOpeningSharedWorld {
                    if findAnchor == "" {
                        Button {
                            showAnchorListSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 65, height: 65)
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.white)
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 10)
                    } else {
                        Button {
                            withAnimation {
                                findAnchor = ""
                            }
                            worldManager.isShowingAll = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 65)
                                Image(systemName: "xmark")
                                    .foregroundStyle(.black)
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                    }
                }
                if findAnchor != "" {
                    Button {
                        worldManager.isShowingAll.toggle()
                        let drop = Drop(title: worldManager.isShowingAll ? "Showing all items" : "Showing \(findAnchor) only")
                        Drops.show(drop)
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(worldManager.isShowingAll ? Color.white : Color.black.opacity(0.5))
                                .frame(width: 65, height: 65)
                            Image(systemName: worldManager.isShowingAll ? "circle.hexagongrid.fill" : "circle.hexagongrid")
                                .foregroundStyle(worldManager.isShowingAll ? .black : .white)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .shadow(color: worldManager.isShowingAll ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                    
                    Button {
                        shouldPlay.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(shouldPlay ? Color.white : Color.black.opacity(0.5))
                                .frame(width: 65, height: 65)
                            Image(systemName: shouldPlay ? "speaker.2.fill" : "speaker.2")
                                .foregroundStyle(shouldPlay ? .black : .white)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .shadow(color: shouldPlay ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                }
            }
            .padding()
            HStack {
                if newAnchorsCount > 0 {
                    Button {
                        if let coordinator = coordinatorRef {
                            coordinator.addNewAnchorsFromPublicDatabase()
                            worldManager.shouldDeletePublicAnchors = true
                            withAnimation {
                                newAnchorsCount = 0
                            }
                        }
                    } label: {
                        Text("Retrieve New Items")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.blue)
                            .cornerRadius(22)
                            .shadow(color: Color.blue.opacity(0.4), radius: 10)
                    }
                }
                Button {
                    if AppState.shared.isiCloudShare {
                        AppState.shared.isiCloudShare = false
                    }
                    if AppState.shared.isViewOnly {
                        AppState.shared.isViewOnly = false
                    }
                    isFlashlightOn = false
                    shouldPlay = false
                    findAnchor = ""
                    worldManager.isWorldLoaded = false
                    guard !currentRoomName.isEmpty else { return }
                    if !isOpeningSharedWorld {
                        coordinatorRef?.stopAudio()
                        
                        
                        worldManager.saveWorldMap(for: currentRoomName, sceneView: coordinatorRef?.parent.sceneView ?? sceneView)
                        
                        
                        
                        let drop = Drop(title: "\(currentRoomName) saved")
                        Drops.show(drop)
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    } else {
                        AppState.shared.isViewOnly = false
                        coordinatorRef?.stopAudio()
                        coordinatorRef?.pauseSession()
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.black)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .cornerRadius(22)
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                }
                .onAppear {
                    // (Optional onAppear code)
                }
            }
            .padding(.horizontal)
        }
    }
}
}

// MARK: - Helper Functions
extension AugmentedView {
    func playItshereMP3(sound: String, withAngle angle: Double) {
        guard let fileURL = Bundle.main.url(forResource: sound, withExtension: "mp3") else {
            print("❌ Could not find \(sound).mp3 in the project bundle.")
            return
        }
        
        // Map the angle to a pan value between -1.0 (full left) and 1.0 (full right).
        // Assuming -90° maps to -1.0, 0° to 0.0, and 90° to 1.0.
        let panValue = max(-1, min(Float(angle / 90.0), 1))
        audioPlayer.pan = panValue
        
        let minDistance: Double = 0.9
         let maxDistance: Double = 3.0
         let volume: Float
         if distance < minDistance {
             volume = 1.0
         } else if distance < maxDistance {
             let factor = Float((distance - minDistance) / (maxDistance - minDistance))
             volume = 1.0 - factor * 0.7 // 1.0 to 0.3 decrease
         } else {
             volume = 0.3
         }
         audioPlayer.volume = volume
        
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            // Attach and connect the audio player if not already done.
            audioEngine.attach(audioPlayer)
            audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
            audioPlayer.play()
        } catch {
            print("❌ Error loading/playing \(sound).mp3: \(error)")
        }
    }
    func onViewAppear() {
    if let arWorldMap = WorldManager.shared.sharedARWorldMap {
        recordName = AppState.shared.publicRecordName
        isOpeningSharedWorld = true
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            node.removeFromParentNode()
        }
        sceneView.debugOptions = []
        sceneView.session.pause()
        let configuration = ARWorldTrackingConfiguration()
        configuration.initialWorldMap = arWorldMap
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.sceneReconstruction = .mesh
        }
        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
            coordinator.worldIsLoaded = false
            coordinator.isLoading = true
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
            coordinator.worldIsLoaded = true
            print("World loaded. Ready to add new guide anchors.")
        }
        DispatchQueue.main.async {
            if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                sceneView.delegate = coordinator
                sceneView.session.delegate = coordinator
                print("Reassigned delegate after loading shared world.")
            }
        }
        worldManager.isWorldLoaded = true
        worldManager.isShowingARGuide = true
        print("World map loaded successfully.")
        print("✅ AR session started with the iCloud-shared map!")
        WorldManager.shared.sharedARWorldMap = nil
    } else {
        isOpeningSharedWorld = false
        worldManager.loadSavedWorlds {
            if let world = worldManager.savedWorlds.first(where: { $0.name == currentRoomName }),
                world.isCollaborative {
                isCollab = true
                recordName = world.publicRecordName ?? ""
                print("This world has public collaboration")
            }
            worldManager.getAnchorNames(for: currentRoomName) { fetchedAnchors in
                DispatchQueue.main.async {
                    if let world = worldManager.savedWorlds.first(where: { $0.name == currentRoomName }),
                        world.isCollaborative,
                        let recordName = world.publicRecordName {
                        iCloudManager.shared.fetchNewAnchors(for: recordName) { records in
                            DispatchQueue.main.async {
                                let fetchedNewAnchorNames = records.compactMap { $0["name"] as? String }
                                newAnchorsCount = fetchedNewAnchorNames.filter { !fetchedAnchors.contains($0) }.count
                                print("Fetched \(newAnchorsCount) new collaborative anchors.")
                            }
                        }
                    }
                }
            }
            guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
            hasLoadedWorldMap = true
            worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
        }
    }
}
    
    func updateScanningProgress() {
    DispatchQueue.main.async {
        let totalZones = Float(worldManager.scanningZones.count)
        let scannedZonesCount = Float(worldManager.scannedZones.count)
        progress = scannedZonesCount / totalZones
        let scanningOrder = [
            "Front Wall",
            "Left Wall",
            "Right Wall",
            "Floor",
            "Ceiling"
        ]
        if let nextZone = scanningOrder.first(where: { !worldManager.scannedZones.contains($0) }) {
            currentInstruction = "Please scan the \(nextZone)."
        } else {
            currentInstruction = "Scanning complete! All zones covered."
        }
    }
}
    
    func playItshereMP3(sound: String) {
    guard let fileURL = Bundle.main.url(forResource: sound, withExtension: "mp3") else {
        print("❌ Could not find \(sound).mp3 in the project bundle.")
        return
    }
    do {
        let audioFile = try AVAudioFile(forReading: fileURL)
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
        audioPlayer.play()
    } catch {
        print("❌ Error loading/playing \(sound).mp3: \(error)")
    }
}
    
    func toggleFlashlight() {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
        print("Flashlight not available on this device")
        return
    }
    do {
        try device.lockForConfiguration()
        if isFlashlightOn {
            device.torchMode = .off
        } else {
            try device.setTorchModeOn(level: 1.0)
        }
        isFlashlightOn.toggle()
        device.unlockForConfiguration()
    } catch {
        print("Failed to toggle flashlight: \(error)")
    }
}
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
            if char.isEmoji {
                return String(char)
            }
        }
        return nil
    }
}

struct ProgressBar: View {
    var progress: Float
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .frame(height: 20)
                .foregroundColor(.gray.opacity(0.3))
            RoundedRectangle(cornerRadius: 10)
                .frame(width: CGFloat(progress) * 300, height: 20)
                .foregroundColor(.blue)
        }
    }
}
