import SwiftUI
import CloudKit
import AnimateText
import CoreHaptics
import ARKit
import AVFoundation
import Drops


enum Direction {
    case inFront
    case onRight
    case onLeft
    case behindYou

    static func classify(angle: Double) -> String {
        switch angle {
        case -30...30:
            return "In Front"
        case -160..<(-30):
            return "On Right"
        case 30...160:
            return "On Left"
        default: // Covers angles less than -160 or greater than 160
            return "Behind You"
        }
    }
}


struct ContentView: View {
    
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
    @GestureState private var isPressed = false // Gesture state variable for press detection
    
    @State private var angle: Double = 0.0 // Store the angle for the arrow rotation
    @State private var distance: Double = 0.0
    @State private var itshere = ""
    @State private var animatedAngle = ""
    @State private var isOpeningSharedWorld = false
    @State private var showAnchorListSheet = false
    @State private var isCollab = false
    @State private var recordId: String = ""
    @Namespace private var arrowNamespace
    @Namespace private var itshereNamespace

    @State private var newAnchorsCount: Int = 0
    @State private var coordinatorRef: ARViewContainer.Coordinator? = nil
    @State private var isCameraPointingDown: Bool = false
    @State private var hasPlayedItshere = false

    var body: some View {
        NavigationStack {
            
            
            VStack {
                ZStack {
                    
                    
                    ARViewContainer(sceneView: sceneView,
                                    anchorName: $currentAnchorName,
                                    worldManager: worldManager,
                                    findAnchor: $findAnchor,
                                    showFocusedAnchor: $isShowingFocusedAnchor,
                                    shouldPlay: $shouldPlay,
                                    isEditingAnchor: $isEditingAnchor,
                                    nameOfAnchorToEdit: $nameOfAnchorToEdit,
                                    angle: $angle,
                                    distanceForUI: $distance, roomName: currentRoomName, isCollab: $isCollab,
                                    recordID: $recordId,
                                    isCameraPointingDown: $isCameraPointingDown,
                                    onCoordinatorMade: { coord in
                                                       coordinatorRef = coord
                                                   })
                    .onAppear {
//                        if AppState.shared.isiCloudShare {
//                            WorldManager.shared.loadSavedWorlds {
//                                print("Loaded saved worlds: \(WorldManager.shared.savedWorlds)")
//                                WorldManager.shared.restoreCollaborativeWorldAndRestartSession(sceneView: sceneView)
//                                
//                            }
//                        }
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
                    
                    
                    
                    if isCameraPointingDown && worldManager.isRelocalizationComplete {
                        ZStack {
                            
                            VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                                .edgesIgnoringSafeArea(.all)
                            // Optionally animate the change
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
                                                    // .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
                                                        .shadow(color: Color.orange.opacity(0.1), radius: 10)
                                                        .symbolEffect(.pulse)
                                                    
                                                    
                                                }
                                                if distance > 0.2 {
                                                    Image(systemName: "circle.fill")
                                                        .font(.system(size: 240, weight: .bold))
                                                        .foregroundStyle(.orange.opacity(0.7))
                                                    //  .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
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
                                        } else {
                                            
                                        }
                                        
                                    }
                                    .rotationEffect(Angle(degrees: -angle))
                                    .animation(.easeInOut(duration: 0.5), value: angle)
                                    
                                }
                                
                            }
                        }
                      }
                    
                    
                    
                    if worldManager.isRelocalizationComplete {
                        VStack {
                            Spacer()
                            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                                .frame(width: UIScreen.main.bounds.width, height: 200)
                                .cornerRadius(22)
                        }
                        .ignoresSafeArea()
                    }
                    
                    
                    
                    if !worldManager.isShowingARGuide || !worldManager.isRelocalizationComplete {
                        
                        ZStack {
                            
                            CircleView(text: !findAnchor.isEmpty ? findAnchor.filter { !$0.isEmoji } : currentRoomName, emoji: extractEmoji(from: findAnchor) ?? "🔍")
                                .padding(.top)
                            
                                .frame(width: 800, height: 800)
                            
                            
                            
                            VStack {
                                Spacer()
                                Button {
                                    // toggleFlashlight()
                                } label: {
                                    
                                    
                                    Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .font(.title)

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
                                        .updating($isPressed) { currentState, gestureState, transaction in
                                            gestureState = currentState
                                        }
                                        .onEnded { _ in
                                            
                                            toggleFlashlight()
                                            
                                            // Trigger the bouncy animation
                                            animateButton = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                animateButton = false
                                            }
                                        }
                                )
                                .sensoryFeedback(.impact(weight: .heavy, intensity: 5), trigger: isFlashlightOn)
                                
                                .padding(30)
                            }
                            .padding()
                        }
                        
                    } else {
                        VStack {
                            if !directLoading {
                                ProgressBar(progress: progress)
                                    .padding()
                                
                                // Scanning Instructions
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
                                                        .onChange(of: angle) {
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
                                            
//                                            PaperPlane3DView(angle: -angle)
//                                          
//                                                .frame(width: 200, height: 70, alignment: .leading)
//                                                // Keep the same matchedGeometryEffect if desired:
//                                                .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
//                                                .transition(.asymmetric(
//                                                    insertion: .scale.combined(with: .opacity),
//                                                    removal: .scale.combined(with: .opacity)))
//                                            //    .animation(.easeInOut(duration: 0.7), value: angle)
//                                                .shadow(color: Color.white.opacity(0.5), radius: 10)

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
                                            //   worldManager.isAddingAnchor.toggle()
                                            isAddingNewAnchor.toggle()
                                            HapticManager.shared.impact(style: .medium)
                                            
                                        } label: {
                                            ZStack {
                                                
                                                // Solid white background when flashlight is OFF
                                                Circle()
                                                    .fill(Color.white)
                                                    .frame(width: 65, height: 65)
                                                
                                                // Flashlight icon
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
//
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
                                                    
                                                    // Flashlight icon
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
                                                    
                                                    // Solid white background when flashlight is OFF
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 65, height: 65)
                                                    
                                                    // Flashlight icon
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
                                            //  isShowingFocusedAnchor.toggle()
                                            worldManager.isShowingAll.toggle()
                                            let drop = Drop.init(title: worldManager.isShowingAll ? "Showing all items" : "Showing \(findAnchor) only")
                                            Drops.show(drop)
                                            HapticManager.shared.impact(style: .medium)
                                            
                                        } label: {
                                            
                                            ZStack {
                                           
                                                    // Solid white background when flashlight is OFF
                                                    Circle()
                                                        .fill(worldManager.isShowingAll ? Color.white : Color.black.opacity(0.5))
                                                        .frame(width: 65, height: 65)
                                                
                                                // Flashlight icon
                                                Image(systemName: worldManager.isShowingAll ? "circle.hexagongrid.fill" : "circle.hexagongrid")
                                                    .foregroundStyle(worldManager.isShowingAll ? .black : .white)
                                                    .font(.title2)
                                                
                                                    .bold()
                                            }
                                        }
                                        .shadow(color:worldManager.isShowingAll ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                                        
                                        Button {
                                            shouldPlay.toggle()
                                            HapticManager.shared.impact(style: .medium)
                                            
                                        } label: {
                                            
                                            ZStack {
                                         
                                                    // Solid white background when flashlight is OFF
                                                    Circle()
                                                    .fill(shouldPlay ? Color.white : Color.black.opacity(0.5))
                                                        .frame(width: 65, height: 65)
                                                
                                                // Flashlight icon
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
                                            if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                                                
                                                coordinator.addNewAnchorsFromPublicDatabase()
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
                                        isFlashlightOn = false
                                        shouldPlay = false
                                        findAnchor = ""
                                        worldManager.isWorldLoaded = false
                                        
                                        
                                        
                                        guard !currentRoomName.isEmpty else { return }
                                        
                                        if !isOpeningSharedWorld {
                                            coordinatorRef?.stopAudio()

                                            worldManager.saveWorldMap(for: currentRoomName, sceneView: sceneView)
                                            
                                            let drop = Drop.init(title: "\(currentRoomName) saved")
                                            Drops.show(drop)
                                            
                                            HapticManager.shared.notification(type: .success)
                                            
                                            dismiss()

                                        } else {
                                            AppState.shared.isViewOnly = false
                                            coordinatorRef?.stopAudio()
                                            coordinatorRef?.pauseSession()

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
                                        //                                        guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
                                        //                                        hasLoadedWorldMap = true
                                        //
                                        //                                        worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
                                    }
                                    
                                    
                                    
                                    
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                    }
                    
                    
                    
                    
                    
                    
                    
                   
                    
                    
                    
                }
                
                
                
            }
            .onAppear {

                    // 1) If we have an iCloud-shared map, load it right away
                if let arWorldMap = WorldManager.shared.sharedARWorldMap {
           
                    recordId = AppState.shared.publicRecordName
                        isOpeningSharedWorld = true
                    
                    
                    sceneView.scene.rootNode.enumerateChildNodes { node, _ in
                            node.removeFromParentNode()
                        }
                        
                        // Also remove any debug overlays if present
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
                        // Re-assign the coordinator so it isn't nil
                        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                            sceneView.delegate = coordinator
                            sceneView.session.delegate = coordinator
                            print("Reassigned delegate after loading shared world.")
                        }
                    }
                    worldManager.isWorldLoaded = true
                    worldManager.isShowingARGuide = true
                    print("World map for loaded successfully.")
                        
                        print("✅ AR session started with the iCloud-shared map!")
                        
                        // If you only want to load it once, clear it out:
                        WorldManager.shared.sharedARWorldMap = nil
                    
                    } else {
                        isOpeningSharedWorld = false
                        // 2) If there's NO shared map, do local “directLoading” stuff
                        worldManager.loadSavedWorlds {
                            
                            if let world = worldManager.savedWorlds.first(where: { $0.name == currentRoomName }), world.isCollaborative {
                                isCollab = true
                                recordId = world.cloudRecordID ?? ""
                                print("this world has public collaboration")

                            }
                            
                            guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
                            hasLoadedWorldMap = true
                            worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
                        }
                    }
                
                
                worldManager.loadSavedWorlds {
                    worldManager.getAnchorNames(for: currentRoomName) { fetchedAnchors in
                           DispatchQueue.main.async {
                               
                               // Now, if the world is collaborative, fetch new anchors
                               if let world = worldManager.savedWorlds.first(where: { $0.name == currentRoomName }),
                                  world.isCollaborative,
                                  let publicRecordID = world.cloudRecordID {
                                   
                                   let recordID = CKRecord.ID(recordName: publicRecordID)
                                   iCloudManager.shared.fetchNewAnchors(for: recordID) { records in
                                       DispatchQueue.main.async {
                                           // Extract new anchor names from the records (assuming each record has a "name" field)
                                           let fetchedNewAnchorNames = records.compactMap { $0["name"] as? String }
                                          
                                           
                                           // Only add new anchors that are not already present
                                           newAnchorsCount = fetchedNewAnchorNames.filter { !fetchedAnchors.contains($0) }.count
                                           
                                           print("Fetched \(newAnchorsCount) new collaborative anchors.")
                                       }
                                   }
                               }
                           }
                       }
                }

                
            }
            .onChange(of: distance) { newDistance in
                      // If you only want to play once each time we cross below 0.3:
                      if newDistance < 0.3 && !hasPlayedItshere {
                          hasPlayedItshere = true
                          playItshereMP3()
                      } else if newDistance > 0.3 {
                          // Reset so we can play again if the user goes away and comes back
                          hasPlayedItshere = false
                      }
                  }
            .onChange(of: worldManager.scannedZones) {
                updateScanningProgress()
            }
            .onChange(of: worldManager.isShowingAll) {
                // We can access the coordinator if needed:
               
                coordinatorRef?.updateNodeVisibility(in: sceneView)
                
            }
            .sheet(isPresented: $showAnchorListSheet) {
                    AnchorListSheet(sceneView: sceneView, onSelectAnchor: { selectedAnchorName in
                        // For instance, make it your findAnchor
                        findAnchor = selectedAnchorName
                        print(findAnchor)
                        worldManager.isShowingAll = false
                        showAnchorListSheet = false
                    })
                    .presentationDetents([.medium, .large])
                }
            .sheet(isPresented: $isAddingNewAnchor) {
                AddAnchorView(anchorName: $currentAnchorName, worldManager: worldManager)
                    .presentationDetents([.fraction(0.6)])
                
            }
            .sheet(isPresented: $isEditingAnchor) {
                EditAnchorView(
                    anchorName: $nameOfAnchorToEdit,
                    onDelete: { anchorName in
                        // 1️⃣ Access the Coordinator via sceneView.delegate
                        DispatchQueue.main.async {
                                       if let coordinator = coordinatorRef {  // <— use the stable reference
                                           coordinator.deleteAnchor(anchorName: anchorName, recId: recordId)
                                       } else {
                                           print("Coordinator is nil — even with stable ref (unexpected).")
                                       }
                                   }
                        // Optionally dismiss the sheet:
                        isEditingAnchor = false
                    },
                    onMove: { anchorName in
                        
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {                            coordinator.prepareToMoveAnchor(anchorName: anchorName, recId: recordId)
                            }
                        }
                        // Optionally dismiss the sheet:
                        isEditingAnchor = false
                    },
                    onRename: { oldName, newName in
                        
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.renameAnchor(oldName: oldName, newName: newName, recId: recordId)
                            }
                        }
                        // Optionally dismiss the sheet:
                        isEditingAnchor = false
                    }
                )
                .presentationDetents([.fraction(0.6)])
                
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if AppState.shared.isiCloudShare {
                            AppState.shared.isiCloudShare = false
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            worldManager.deleteWorld(roomName: currentRoomName) {
                                print("Deletion process completed.")
                                HapticManager.shared.notification(type: .success)
                                
                                dismiss()
                            }
                        } label: {
                            Label("Delete World", systemImage: "trash")
                        }
                        
                        Button {
                            worldManager.shareWorld(currentRoomName: currentRoomName)
                        } label: {
                            Label("Share World", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                
            }
            
        }
        
    }
    
    
    
    
    // Function to toggle flashlight
    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            print("Flashlight not available on this device")
            return
        }
        
        do {
            try device.lockForConfiguration()
            if isFlashlightOn {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: 1.0) // Maximum brightness
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
    
    private func updateScanningProgress() {
        DispatchQueue.main.async {
            let totalZones = Float(worldManager.scanningZones.count)
            let scannedZonesCount = Float(worldManager.scannedZones.count)
            progress = scannedZonesCount / totalZones
            
            // List the zones in the order you'd like them scanned,
            // but the user can scan them in *any* order and we'll still update accordingly.
            let scanningOrder = [
                "Front Wall",
                "Left Wall",
                "Right Wall",
                "Floor",
                "Ceiling"
            ]
            
            // Check which zone from scanningOrder is still unscanned
            if let nextZone = scanningOrder.first(where: { !worldManager.scannedZones.contains($0) }) {
                // If we found an unscanned zone, guide the user to it
                currentInstruction = "Please scan the \(nextZone)."
            } else {
                // Otherwise, everything is scanned
                currentInstruction = "Scanning complete! All zones covered."
            }
        }
    }
    
    private func playItshereMP3() {
          guard let fileURL = Bundle.main.url(forResource: "itshere", withExtension: "mp3") else {
              print("❌ Could not find itshere.mp3 in the project bundle.")
              return
          }
          do {
              let audioFile = try AVAudioFile(forReading: fileURL)
              
              // Attach and connect the node if not already connected
              audioEngine.attach(audioPlayer)
              audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
              
              // Make sure engine is running
              if !audioEngine.isRunning {
                  try audioEngine.start()
              }
              
              // Schedule file to play once
              audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
              audioPlayer.play()
              
          } catch {
              print("❌ Error loading/playing itshere.mp3: \(error)")
          }
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

// Helper view to add a blur effect
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    var intensity: CGFloat? = nil
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
