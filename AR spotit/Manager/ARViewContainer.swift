import SwiftUI
import ARKit
import CoreHaptics
import Drops
import AVFoundation


struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @Binding var anchorName: String
   
    @ObservedObject var worldManager: WorldManager
    var findAnchor: String
    @State private var tempAnchor: ARAnchor? // For moving the anchor

    @Binding var showFocusedAnchor: Bool
    
    @Binding var shouldPlay: Bool
    // Audio properties
       private let audioEngine = AVAudioEngine()
       private let audioPlayer = AVAudioPlayerNode()
       private let audioEnvironmentNode = AVAudioEnvironmentNode()
    @State private var findAnchorReference: ARAnchor?

    @Binding var isEditingAnchor: Bool
    @Binding var nameOfAnchorToEdit: String
    
    private func stopAudio() {
        audioPlayer.stop()
          audioEngine.stop()
          print("Audio stopped.")
      }
    
    func makeUIView(context: Context) -> ARSCNView {
        sceneView.delegate = context.coordinator
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.sceneReconstruction = .mesh
            configuration.frameSemantics.insert(.sceneDepth)
            print("Scene reconstruction with LiDAR enabled.")
        } else {
            print("LiDAR-based scene reconstruction is not supported on this device.")
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session.delegate = context.coordinator as any ARSessionDelegate
     //   sceneView.antialiasingMode = .multisampling4X
        //sceneView.scene.lightingEnvironment.intensity = 0.1 // Lower the intensity for a darker environment
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleLongPress(_:))
        )
        
        
        sceneView.addGestureRecognizer(longPressGesture)
        
        sceneView.addGestureRecognizer(tapGesture)
        
       
       // setupAudio()
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    
 
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self, worldManager: worldManager)
//        coordinator.createImageFromLabel = { text, font, textColor, backgroundColor, size in
//            self.imageFromLabel(text: text, font: font, textColor: textColor, backgroundColor: backgroundColor, size: size)
//        }
        return coordinator
    }
    
    private func setupAudio() {
        configureAudioSession()

        
            // Load the audio file
            guard let audioFileURL = Bundle.main.url(forResource: "Morse", withExtension: "aiff"),
                  let audioFile = try? AVAudioFile(forReading: audioFileURL) else {
                print("Audio file not found.")
                return
            }

            // Attach nodes
            audioEngine.attach(audioPlayer)
            audioEngine.attach(audioEnvironmentNode)

            // Connect nodes
            audioEngine.connect(audioPlayer, to: audioEnvironmentNode, format: nil)
            audioEngine.connect(audioEnvironmentNode, to: audioEngine.mainMixerNode, format: nil)

            // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
        // Loop the audio file indefinitely
            func scheduleAudio() {
                audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                scheduleAudio() // Recursively schedule audio with a delay
                            }
                })
            }

            scheduleAudio()
            audioPlayer.play()
        }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playback category and spatial mode
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            print("Audio session configured for spatial audio.")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
  
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate, Sendable {
        private var lastAnimationUpdateTime: Date = Date()
        private var hapticEngine: CHHapticEngine?
        private var lastHapticTriggerTime: Date = Date()
        private var nextPulseTime: Date = .distantPast
        var parent: ARViewContainer
        var worldManager: WorldManager
        private var mergedMeshNode = SCNNode() // Merged mesh node for all anchors
        private var lastUpdateTime: Date = Date() // Throttle updates
        private let maxGuideAnchors = 50  // Example maximum number of guide anchors
        var placedGuideAnchors: [(transform: simd_float4x4, anchor: ARAnchor)] = []
        private var anchorGrid: [Int: [ARAnchor]] = [:]
        private let gridSize: Float = 1.0
        var worldIsLoaded: Bool = false
        private var duplicateDistanceThreshold: Float = 1
        var isLoading = false
        var processedPlaneAnchorIDs: Set<UUID> = []
        private var relocalizationTask: Task<Void, Never>?
        private var zoneEntryTimes: [String: Date] = [:]
        private var currentArrowNode: SCNNode?
        private var anchorNodes: [String: SCNNode] = [:]
        private var lastJumpHeight: Float = 0.0

        private var nodeBasePositions = [String: SCNVector3]()
        private var nodeJumpHeights = [String: Float]()
        private var isAudioPlaying = true


        
        init(_ parent: ARViewContainer, worldManager: WorldManager) {
            self.parent = parent
            self.worldManager = worldManager
            super.init()
            setupHaptics()
            setupScanningZones()
        }
        
        
        
        func updateNodeVisibility(in sceneView: ARSCNView) {
                    let allNodes = sceneView.scene.rootNode.childNodes
                    for node in allNodes {
                        refreshVisibilityRecursive(node: node)
                    }
                }
                
        private func refreshVisibilityRecursive(node: SCNNode) {
                    // If the ARKit anchor's name is stored in `node.name`, we can rely on it here.
                    guard let nodeName = node.name else {
                        // Recur into children anyway, in case sub-nodes have meaningful names
                        for child in node.childNodes {
                            refreshVisibilityRecursive(node: child)
                        }
                        return
                    }
                    
                    // If isShowingAll => show everything => node.isHidden = false
                       // If !isShowingAll => only show findAnchor => hide node if it’s not findAnchor
                    let shouldHide = !worldManager.isShowingAll && (nodeName != parent.findAnchor)
                       node.isHidden = shouldHide

                       for child in node.childNodes {
                           refreshVisibilityRecursive(node: child)
                       }
                }
        
        private func setupHaptics() {
               guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
                   print("Haptics not supported on this device.")
                   return
               }
               do {
                   hapticEngine = try CHHapticEngine()
                   try hapticEngine?.start()
               } catch {
                   print("Failed to start haptic engine: \(error)")
               }
           }
        
        func provideHapticFeedback(for distance: Float) {
                guard let hapticEngine = hapticEngine, Date().timeIntervalSince(lastHapticTriggerTime) > 0.1 else {
                    return
                }
                lastHapticTriggerTime = Date()
                
                let intensity = min(1.0, max(0.1, 1.0 - distance / 3.0)) // Closer = higher intensity
                let sharpness = intensity
                
                let events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                        ],
                        relativeTime: 0,
                        duration: 0.1
                    )
                ]
                
                do {
                    let pattern = try CHHapticPattern(events: events, parameters: [])
                    let player = try hapticEngine.makePlayer(with: pattern)
                    try player.start(atTime: CHHapticTimeImmediate)
                } catch {
                    print("Failed to play haptic pattern: \(error)")
                }
            }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            
            if worldManager.isAddingAnchor {
                let sceneView = parent.sceneView
                let location = sender.location(in: sceneView)
                
                // Create a raycast query
                guard let raycastQuery = sceneView.raycastQuery(
                    from: location,
                    allowing: .estimatedPlane,
                    alignment: .horizontal
                ) else {
                    print("Failed to create raycast query.")
                    return
                }
                
                // Perform the raycast
                let results = sceneView.session.raycast(raycastQuery)
                
                // Use the first result if available
                guard let result = results.first else {
                    print("No raycast result found.")
                    return
                }
                
                // Place anchor at the raycast result's position
                let name = parent.anchorName.isEmpty ? "defaultAnchor" : parent.anchorName
                let anchor = ARAnchor(name: name, transform: result.worldTransform)
                sceneView.session.add(anchor: anchor)
                print("Placed anchor with name: \(name) at position: \(result.worldTransform.columns.3)")
                worldManager.isAddingAnchor = false
            } else {
                if parent.tempAnchor != nil {
                    let sceneView = parent.sceneView
                    let location = sender.location(in: sceneView)
                    
                    // Create a raycast query
                    guard let raycastQuery = sceneView.raycastQuery(
                        from: location,
                        allowing: .estimatedPlane,
                        alignment: .horizontal
                    ) else {
                        print("Failed to create raycast query.")
                        return
                    }
                    
                    // Perform the raycast
                    let results = sceneView.session.raycast(raycastQuery)
                    
                    // Use the first result if available
                    guard let result = results.first else {
                        print("No raycast result found.")
                        return
                    }
                    
                   
                    if let tempAnchor = parent.tempAnchor {
                            // Place the saved anchor at a new position
                            let newAnchor = ARAnchor(name: tempAnchor.name ?? "defaultAnchor", transform: result.worldTransform)
                            sceneView.session.add(anchor: newAnchor)
                            parent.tempAnchor = nil
                            print("Anchor moved to new position.")
                        } else {
                            print("No anchor to move.")
                        }
                }
            }
        }
        
        @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
            guard sender.state == .began else { return } // Only handle on gesture start

            let location = sender.location(in: parent.sceneView)
            let hitResults = parent.sceneView.hitTest(location)

            print("Hit test results:")
            for result in hitResults {
                print("Node name: \(result.node.name ?? "nil")")
            }

            guard let hitResult = hitResults.first else {
                print("No hit results found.")
                return
            }

            // Traverse the node hierarchy to find the named node
            var currentNode: SCNNode? = hitResult.node
            while let node = currentNode {
                if let name = node.name {
                    print("Found anchor with name: \(name)")
                    parent.nameOfAnchorToEdit = name
                    parent.isEditingAnchor = true
                    
                  //  presentAnchorOptions(anchorName: name, node: node)
                    return
                }
                currentNode = node.parent
            }

            print("No anchor hit detected in node hierarchy.")
        }
        
        func deleteAnchor(anchorName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
                print("Anchor with name \(anchorName) not found.")
                return
            }
            

            parent.sceneView.session.remove(anchor: anchor)
            print("Anchor '\(anchorName)' deleted.")
        }
        
        func renameAnchor(oldName: String, newName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == oldName }) else {
                print("Anchor with name \(oldName) not found.")
                return
            }

            // Create a new anchor with the updated name
            let newAnchor = ARAnchor(name: newName, transform: anchor.transform)
            parent.sceneView.session.remove(anchor: anchor)
            parent.sceneView.session.add(anchor: newAnchor)
            
            print("Anchor renamed from \(oldName) to \(newName).")
        }
        
        func prepareToMoveAnchor(anchorName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
                print("Anchor with name \(anchorName) not found.")
                return
            }

            // Store the anchor temporarily
            parent.tempAnchor = anchor
            parent.sceneView.session.remove(anchor: anchor)
            print("Anchor '\(anchorName)' prepared for moving.")
        }
        
        private func setupScanningZones() {
            let origin = matrix_identity_float4x4 // Identity at origin

            // Some example “wall” offsets from the origin
            let frontWallTranslation = matrix_float4x4.translation(SIMD3<Float>(0, 0, -2))
            let leftWallTranslation  = matrix_float4x4.translation(SIMD3<Float>(-2, 0, 0))
            let rightWallTranslation = matrix_float4x4.translation(SIMD3<Float>(2, 0, 0))
            let floorTranslation     = matrix_float4x4.translation(SIMD3<Float>(0, -1.5, 0))
            let ceilingTranslation   = matrix_float4x4.translation(SIMD3<Float>(0, 2, 0))

            DispatchQueue.main.async {
                self.worldManager.scanningZones = [
                    "Front Wall": simd_mul(origin, frontWallTranslation),
                    "Left Wall":  simd_mul(origin, leftWallTranslation),
                    "Right Wall": simd_mul(origin, rightWallTranslation),
                    "Floor":      simd_mul(origin, floorTranslation),
                    "Ceiling":    simd_mul(origin, ceilingTranslation)
                ]
            }
        }
        
        func checkZoneCoverage(for position: SIMD3<Float>) {
            for (zoneName, zoneTransform) in worldManager.scanningZones {
                let zonePosition = SIMD3<Float>(zoneTransform.columns.3.x,
                                                zoneTransform.columns.3.y,
                                                zoneTransform.columns.3.z)
                
                if simd_distance(position, zonePosition) < 1.5 {
                    // If user is within 1.5m of that zone
                    if !worldManager.scannedZones.contains(zoneName) {
                        DispatchQueue.main.async {
                            self.worldManager.scannedZones.insert(zoneName)
                        }
                        print("\(zoneName) scanned after 2 seconds.")
                    }
                }
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            node.name = anchor.name
            anchorNodes[anchor.name ?? ""] = node

            let anchorPosition = SIMD3<Float>(anchor.transform.columns.3.x,
                                              anchor.transform.columns.3.y,
                                              anchor.transform.columns.3.z)
            checkZoneCoverage(for: anchorPosition)
            
            if let planeAnchor = anchor as? ARPlaneAnchor {
                adjustMaxGuideAnchors(basedOn: planeAnchor)
                addGuideAnchorIfNeeded(newTransform: planeAnchor.transform)
            }
            
            // Visualization logic for “guide” anchor
            if let anchorName = anchor.name, anchorName == "guide" {
                let guideGeometry = SCNSphere(radius: 0.001)
                guideGeometry.firstMaterial?.diffuse.contents = UIColor.white
                let guideNode = SCNNode(geometry: guideGeometry)
                node.addChildNode(guideNode)
                
                print("Visualizing guide anchor at position: \(anchor.transform.columns.3)")
                return
            }
            
            // For user-labeled anchors
            guard let anchorName = anchor.name else {
                print("No name found for anchor, skipping visualization.")
                return
            }
            
            print("Visualizing anchor with name: \(anchorName)")
            
            
            
            // 1) Show sphere or emoji
            let emoji = parent.extractEmoji(from: anchorName)
            if let emoji = emoji {
                let glassEmojiNode = createGlassEmojiNode(emoji: emoji)
                   node.addChildNode(glassEmojiNode)
                // If an emoji is present, create a flat plane with the emoji

            } else {
                let sphereGeometry = SCNSphere(radius: 0.03)
                sphereGeometry.firstMaterial?.diffuse.contents = UIColor.white
                let sphereNode = SCNNode(geometry: sphereGeometry)
                node.addChildNode(sphereNode)
            }
//
            
            
                        let cleanAnchorName = anchorName.filter { !$0.isEmoji }
                        
                        // Make an image for the text
                        let labelFont: UIFont = {
                            if let descriptor = UIFontDescriptor
                                .preferredFontDescriptor(withTextStyle: .title2)
                                .withDesign(.rounded) {
                                
                                // Example: size 30
                                return UIFont(descriptor: descriptor, size: 30)
                            } else {
                                // Fallback if .rounded not available
                                return UIFont.systemFont(ofSize: 30)
                            }
                        }()
                        
                        let imageSize = CGSize(width: 400, height: 120)
            DispatchQueue.global(qos: .userInitiated).async {
                
                guard let labelImage = self.parent.imageFromLabel(
                    text: cleanAnchorName,
                    font: labelFont,
                    textColor: .white,
                    backgroundColor: .clear,
                    size: imageSize
                ) else {
                    print("Failed to create label image.")
                    return
                }
                //
                // Create a plane for the text
                let planeWidth: CGFloat = 0.3
                let planeHeight: CGFloat = 0.09 // a bit shorter than the width
                let textPlane = SCNPlane(width: planeWidth, height: planeHeight)
                
                let textMaterial = SCNMaterial()
                textMaterial.diffuse.contents = labelImage
                textMaterial.isDoubleSided = true
                textMaterial.lightingModel = .constant

                textPlane.materials = [textMaterial]
                
                let textNode = SCNNode(geometry: textPlane)
                // Position above the emoji or sphere
                textNode.position = SCNVector3(0, 0.07, 0)
                
                // Let the text face camera
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .Y
                textNode.constraints = [billboardConstraint]
                
                node.addChildNode(textNode)
            }
//
//            let cleanName = anchorName.filter { !$0.isEmoji }
//             guard !cleanName.isEmpty else { return }
//             
//            //  Create the 3D text node
//             let textNode = create3DTextNode(
//                 cleanName,
//                 fontSize: 30,
//                 extrusion: 2,       // try bigger to get more "paint tube" look
//                 chamfer: 200,          // bigger chamfer for rounder edges
//                 color: .white   // or your favorite color
//             )
//             textNode.position = SCNVector3(0, 0.07, 0)
//             
//             // Make text face the camera (if desired)
//             let billboardConstraint = SCNBillboardConstraint()
//             billboardConstraint.freeAxes = .Y
//             textNode.constraints = [billboardConstraint]
             
      //       node.addChildNode(textNode)
            let spotlightNode = SCNNode()
            let spotlight = SCNLight()
            spotlight.type = .spot
            spotlight.spotInnerAngle = 30
            spotlight.spotOuterAngle = 60
            spotlight.intensity = 50
            spotlight.temperature = 10000
        
            spotlight.castsShadow = true // Enable shadows for better visual impact

            spotlightNode.light = spotlight
            spotlightNode.position = SCNVector3(0, 1, 0) // Above and slightly forward
            spotlightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // Point downward
            node.addChildNode(spotlightNode)
        
//            if anchorName == "Fishing rod 🎣" {
//                let audioSource = SCNAudioSource(fileNamed: "Morse.aiff")!
//                audioSource.loops = true
//                audioSource.isPositional = true
//                
//                // Decode the audio from disk ahead of time to prevent a delay in playback
//                audioSource.load()
//                node.addAudioPlayer(SCNAudioPlayer(source: audioSource))
//
//            }
           
          //  addVolumetricSpotlightAbove(node)
            
//            if anchor.name == parent.findAnchor {
//                addVolumetricSpotlightAbove(node)
//                }
            let shouldHide = !worldManager.isShowingAll && (anchorName != parent.findAnchor)
      
                node.isHidden = shouldHide
            
           
            
        }
       
        
        
        
        func createGlassEmojiNode(
            emoji: String,
            bubbleRadius: CGFloat = 0.05  // Radius of the glass sphere
        ) -> SCNNode {
            let parentNode = SCNNode()

            // Glass sphere
            let sphereGeometry = SCNSphere(radius: bubbleRadius)
            let glassMaterial = SCNMaterial()
            glassMaterial.lightingModel = .physicallyBased
            glassMaterial.diffuse.contents = UIColor.clear // Clear base color

            glassMaterial.metalness.contents = 0.0
            glassMaterial.roughness.contents = 0.05
            glassMaterial.diffuse.contents = UIColor(white: 1, alpha: 0.05)
            glassMaterial.transparency = 0.2
            glassMaterial.transparencyMode = .dualLayer
            glassMaterial.writesToDepthBuffer = false // Prevent depth conflicts
            sphereGeometry.materials = [glassMaterial]

            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.renderingOrder = 0

            parentNode.addChildNode(sphereNode)

            // Emoji plane inside the sphere
            DispatchQueue.global(qos: .userInitiated).async {
                let emojiFont = UIFont.systemFont(ofSize: 70)
                let emojiSize = CGSize(width: 70, height: 70)
                
                guard let emojiImage = self.parent.imageFromLabel(
                    text: emoji,
                    font: emojiFont,
                    textColor: .black,
                    backgroundColor: .clear,
                    size: emojiSize
                ) else {
                    print("Failed to create emoji image.")
                    return
                }
                
                DispatchQueue.main.async {
                    let planeSize: CGFloat = bubbleRadius * 1
                    let emojiPlane = SCNPlane(width: planeSize, height: planeSize)
                    let emojiMaterial = SCNMaterial()
                    emojiMaterial.diffuse.contents = emojiImage
                    emojiMaterial.lightingModel = .constant // Ensure emoji ignores scene lighting

                    emojiMaterial.isDoubleSided = true
                    emojiPlane.materials = [emojiMaterial]
                    
                    let emojiNode = SCNNode(geometry: emojiPlane)
                    emojiNode.position = SCNVector3(0, 0, 0.01)
                    emojiNode.renderingOrder = 1
                    // Make the emoji plane face the camera
                    let billboardConstraint = SCNBillboardConstraint()
                    billboardConstraint.freeAxes = .Y
                    emojiNode.constraints = [billboardConstraint]
                    
                    parentNode.addChildNode(emojiNode)
                }
            }

            return parentNode
        }
        func create3DTextNode(
            _ text: String,
            fontSize: CGFloat = 60,
            extrusion: CGFloat = 5,
            chamfer: CGFloat = 2,
            color: UIColor = .systemBlue
        ) -> SCNNode {
            // (A) Create an SCNText geometry
            let scnText = SCNText(string: text, extrusionDepth: extrusion)
            
            // Use a rounded SF font (fallback if not available)
            if let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title1)
                .withDesign(.rounded) {
                scnText.font = UIFont(descriptor: desc, size: fontSize)
            } else {
            //    scnText.font = UIFont.systemFont(ofSize: fontSize)
            }
            
            // (B) Optional: round edges
            scnText.chamferRadius = chamfer
          //  scnText.chamferMode = .both  // Round front & back edges
             //   scnText.flatness = 0.0
            // (C) Material for the text
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.lightingModel = .physicallyBased
            material.metalness.contents = 0    // 0 = non-metal, 1 = fully metallic
            material.roughness.contents = 0.15   // lower roughness => more reflective
            scnText.materials = [material]
            
            // (D) Create a node from the text geometry
            let textNode = SCNNode(geometry: scnText)
            
            // (E) SCNText is sized in *points*. For AR, we usually scale down.
            // For example, scaling to 1/1000 or 1/500 of the default size.
            textNode.scale = SCNVector3(0.001, 0.001, 0.001)
            
            // (F) Center the text around (0,0,0) by adjusting the pivot
            // after boundingBox is calculated
            DispatchQueue.main.async {
                let (minBox, maxBox) = textNode.boundingBox
                let dx = maxBox.x - minBox.x
                let dy = maxBox.y - minBox.y
                let dz = maxBox.z - minBox.z
                textNode.pivot = SCNMatrix4MakeTranslation(dx / 2, dy / 2, dz / 2)
            }
            
            return textNode
        }

        private func pulseInterval(for distance: Float) -> TimeInterval {
                    let maxDistance: Float = 3.0
                    let minInterval: TimeInterval = 0.1
                    let maxInterval: TimeInterval = 1.0
                    
                    // Clamp distance to [0, maxDistance]
                    let clampedDist = max(0, min(distance, maxDistance))
                    // fraction = 0.0 (very close) -> 1.0 (very far)
                    let fraction = clampedDist / maxDistance
                    
            let interval = minInterval + (maxInterval - minInterval) * Double(fraction)
                    return interval
                }
                
        private func playDub() {
                guard let hapticEngine = hapticEngine else { return }
                
                let intensity: Float = 1.0
                let sharpness: Float = 0.5
                
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity,  value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                    ],
                    relativeTime: 0
                )
                
                do {
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let player = try hapticEngine.makePlayer(with: pattern)
                    try player.start(atTime: 0)
                } catch {
                    print("Failed to play haptic pattern: \(error)")
                }
            }
        
        func updateAnchorLighting(intensity: CGFloat, temperature: CGFloat) {
            let normalizedIntensity = min(max(intensity / 1000.0, 0.2), 2.0) // Normalize between 0.2 and 2.0

            for (_, node) in anchorNodes {
                // Adjust emission glow
                if let material = node.geometry?.firstMaterial {
                    material.emission.contents = UIColor(hue: 0.1, saturation: 0.8, brightness: normalizedIntensity, alpha: 1.0)
                }

                // Adjust light temperature
                node.light?.temperature = temperature
                node.light?.intensity = normalizedIntensity * 1000
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            
            if let lightEstimate = frame.lightEstimate {
                   if lightEstimate.ambientIntensity < 100.0 { // Example threshold for low light
                     //  Drops.show("Low light detected. Turn on flash.")
                   }
               }
            
            
            // Throttle updates to avoid excessive computation
               let currentTime = Date()
               guard currentTime.timeIntervalSince(lastAnimationUpdateTime) > 0.2 else { return } // Update every 0.2 seconds
               lastAnimationUpdateTime = currentTime
            // Retrieve light estimation
              if let lightEstimate = frame.lightEstimate {
                  let ambientIntensity = lightEstimate.ambientIntensity // Brightness
                  let ambientColorTemperature = lightEstimate.ambientColorTemperature // Kelvin
                  updateAnchorLighting(intensity: ambientIntensity, temperature: ambientColorTemperature)
              }
            
            // Look for the anchor to track
            guard let anchor = session.currentFrame?.anchors.first(where: { $0.name == parent.findAnchor }) else {
                return
            }

            // Get distance from camera
            let cameraTransform = frame.camera.transform
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                              cameraTransform.columns.3.y,
                                              cameraTransform.columns.3.z)
            let anchorPosition = SIMD3<Float>(anchor.transform.columns.3.x,
                                              anchor.transform.columns.3.y,
                                              anchor.transform.columns.3.z)
            let distance = simd_distance(cameraPosition, anchorPosition)
            let clampedDistance = max(0.1, min(distance, 5.0)) // Clamp distance
            let direction = anchorPosition - cameraPosition

            // Turn distance into a pulsing interval
            let interval = pulseInterval(for: clampedDistance)

            // Trigger haptic feedback if it's time
            if Date() >= nextPulseTime {
                playDub()
                nextPulseTime = Date().addingTimeInterval(interval)
            }
            
            if parent.shouldPlay {
                
                if !isAudioPlaying {
                    isAudioPlaying = true
                    parent.setupAudio()
                    
                }
                // Update audio position
                // Update the listener's position to match the camera
                parent.audioEnvironmentNode.listenerPosition = AVAudio3DPoint(
                    x: cameraPosition.x,
                    y: cameraPosition.y,
                    z: cameraPosition.z
                )
                
                parent.audioEnvironmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
                parent.audioEnvironmentNode.distanceAttenuationParameters.referenceDistance = 1.0 // Reference for volume
                parent.audioEnvironmentNode.distanceAttenuationParameters.maximumDistance = 10.0
                parent.audioEnvironmentNode.distanceAttenuationParameters.rolloffFactor = 1.0
                parent.audioEnvironmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
                
                // Update the audio source's position to match the anchor
                parent.audioEnvironmentNode.position = AVAudio3DPoint(
                    x: direction.x,
                    y: direction.y,
                    z: direction.z
                )
                
                // Adjust volume based on distance
                parent.audioPlayer.volume = max(0.1, 1.0 - (distance / 2.0))
            } else {
                if isAudioPlaying {
                    isAudioPlaying = false
                      DispatchQueue.global(qos: .background).async {
                          self.parent.stopAudio()
                      }
                  }            }
            guard let node = anchorNodes[anchor.name ?? ""] else {
                return
            }
            DispatchQueue.main.async {
                self.addJumpingAnimation(to: node, basedOn: clampedDistance)
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            
            // Throttle updates to once every 0.5 seconds
            if Date().timeIntervalSince(lastUpdateTime) < 0.5 {
                return
            }
            lastUpdateTime = Date()
            
            if !isLoading {
                let meshGeometry = meshAnchor.geometry
                let vertexBuffer = meshGeometry.vertices.buffer
                let vertexCount = meshGeometry.vertices.count
                let stride = meshGeometry.vertices.stride
                let offset = meshGeometry.vertices.offset
                
                var vertices: [SIMD3<Float>] = []
                let pointer = vertexBuffer.contents()
                for i in 0..<vertexCount {
                    let vertexPointer = pointer.advanced(by: i * stride + offset)
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    vertices.append(vertex)
                }
                
                let pointCloudNode = parent.createPointCloudNode(from: vertices)
                node.addChildNode(pointCloudNode)
            }
        }
        
        func addMeshGeometry(from meshAnchor: ARMeshAnchor) {
            let meshGeometry = createSimplifiedMeshGeometry(from: meshAnchor)
            let newNode = SCNNode(geometry: meshGeometry)
            newNode.name = meshAnchor.identifier.uuidString
            mergedMeshNode.addChildNode(newNode)
            
            if mergedMeshNode.parent == nil {
                parent.sceneView.scene.rootNode.addChildNode(mergedMeshNode)
            }
        }
        
        func updateMeshGeometry(from meshAnchor: ARMeshAnchor) {
            let updatedGeometry = createSimplifiedMeshGeometry(from: meshAnchor)
            if let childNode = mergedMeshNode.childNodes.first(where: { $0.name == meshAnchor.identifier.uuidString }) {
                childNode.geometry = updatedGeometry
            } else {
                addMeshGeometry(from: meshAnchor)
            }
        }
        
        func createSimplifiedMeshGeometry(from meshAnchor: ARMeshAnchor) -> SCNGeometry {
            let meshGeometry = meshAnchor.geometry
            
            // Vertex data
            let vertexBuffer = meshGeometry.vertices.buffer
            let vertexSource = SCNGeometrySource(
                buffer: vertexBuffer,
                vertexFormat: .float3,
                semantic: .vertex,
                vertexCount: meshGeometry.vertices.count,
                dataOffset: meshGeometry.vertices.offset,
                dataStride: meshGeometry.vertices.stride
            )
            
            // Face data: sample fewer faces for performance
            let facesBuffer = meshGeometry.faces.buffer
            let totalFaceCount = meshGeometry.faces.count
            let sampledFaceCount = min(totalFaceCount, 5000)
            let indexBufferLength = sampledFaceCount * 3 * MemoryLayout<UInt16>.size
            
            let facesPointer = facesBuffer.contents()
            let indexData = Data(bytes: facesPointer, count: indexBufferLength)
            let geometryElement = SCNGeometryElement(
                data: indexData,
                primitiveType: .triangles,
                primitiveCount: sampledFaceCount,
                bytesPerIndex: MemoryLayout<UInt16>.size
            )
            
            // Create SCNGeometry
            let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.green.withAlphaComponent(0.5)
            material.isDoubleSided = true
            geometry.materials = [material]
            
            return geometry
        }
        
        private func addGuideAnchorIfNeeded(newTransform: simd_float4x4) {
            guard worldIsLoaded else {
                print("Skipping guide anchor placement. Relocalization not complete.")
                return
            }
            
            let position = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
            
            // Check for nearby guide anchors to avoid duplicates
            let isDuplicate = parent.sceneView.session.currentFrame?.anchors.contains(where: { anchor in
                anchor.name == "guide"
                && simd_distance(anchor.transform.columns.3, newTransform.columns.3) < 0.7
            }) ?? false
            
            if !isDuplicate {
                let guideAnchor = ARAnchor(name: "guide", transform: newTransform)
                parent.sceneView.session.add(anchor: guideAnchor)
                print("Added new guide anchor at \(position) in newly exposed area.")
            }
        }
        
        private func adjustMaxGuideAnchors(basedOn planeAnchor: ARPlaneAnchor) {
            let area = planeAnchor.extent.x * planeAnchor.extent.z
            let newMax = Int(area * 10)
            print("Adjusted max guide anchors to \(newMax) based on plane size.")
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            relocalizationTask?.cancel()
            relocalizationTask = Task {
                switch camera.trackingState {
                case .normal:
                    print("Relocalization complete. Ready to add guide anchors.")
                    worldIsLoaded = true
                  

                    try? await Task.sleep(nanoseconds: 500_000_000)
                    DispatchQueue.main.async {
                        withAnimation(.easeIn(duration: 1)) {
                            self.worldManager.isRelocalizationComplete = true

                        }
                    }
                case .limited(.relocalizing):
                    print("Relocalizing...")
                    worldIsLoaded = false
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 1)) {
                            self.worldManager.isRelocalizationComplete = false
                        }
                    }
                default:
                    break
                }
            }
        }
        
        func addJumpingAnimation(to node: SCNNode, basedOn distance: Float) {
            // We need the node's name to track it in our dictionaries
            guard let anchorName = node.name else { return }

            if distance < 1.0 {
                   node.removeAction(forKey: "jumping")
                if let basePos = nodeBasePositions[anchorName] {
                    let moveToOriginal = SCNAction.move(to: basePos, duration: 0.3) // Smooth reset in 0.3 seconds
                    node.runAction(moveToOriginal)
                }
                
                   return
               }
            
            // 1) Figure out the base (original) position in world coordinates
            //    so the node always returns to exactly that spot.
            let basePos: SCNVector3
            if let storedPos = nodeBasePositions[anchorName] {
                // We already stored a base position
                basePos = storedPos
            } else {
                // First time we see this node, record its current *rendered* position
                basePos = node.presentation.position
                nodeBasePositions[anchorName] = basePos
            }

            // 2) Compute the new jump height: far anchor => bigger jump, near => smaller
            let maxJump: Float = 0.9 // max 0.5m up
            let clampedDist = max(0.1, min(distance, 3.0)) // keep distance in [0.1 ... 3.0]
            let newJump = maxJump * (clampedDist / 3.0) // range ~0..0.5
            // (Optional) you can clamp if you want to absolutely ensure 0 <= newJump <= 0.5:
            // let newJump = max(0.0, min(tempJump, maxJump))

            // 3) Check if this jump height is significantly different from last time.
            let oldJump = nodeJumpHeights[anchorName] ?? 0.0
            let delta = abs(newJump - oldJump)
            // If too small a difference, skip re-starting the animation.
            if delta < 0.05 {
                return
            }
            // Update the recorded jump height.
            nodeJumpHeights[anchorName] = newJump

            // 4) Remove any existing jump, so we don't overlap animations.
            node.removeAction(forKey: "jumping")

            // 5) Create an absolute “move(to:)” up, then down. This guarantees no drift.
            let upPosition   = SCNVector3(basePos.x, basePos.y + newJump, basePos.z)
            let downPosition = basePos

            let moveUp   = SCNAction.move(to: upPosition,   duration: 0.5)
            let moveDown = SCNAction.move(to: downPosition, duration: 0.5)
            let jumpCycle = SCNAction.sequence([moveUp, moveDown])
            let repeatJump = SCNAction.repeatForever(jumpCycle)

            // 6) Run the repeatForever
            node.runAction(repeatJump, forKey: "jumping")
        }
    }
}

// MARK: - Helper functions for generating images & point clouds

extension ARViewContainer {
    func createPointCloudNode(from vertices: [SIMD3<Float>]) -> SCNNode {
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.size)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        var indices = [Int32](0..<Int32(vertices.count))
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<Int32>.size)
        
        let pointElement = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        let pointMaterial = SCNMaterial()
        pointMaterial.diffuse.contents = UIColor.white
        pointMaterial.lightingModel = .constant
        pointMaterial.isDoubleSided = true
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [pointElement])
        geometry.materials = [pointMaterial]
        
        return SCNNode(geometry: geometry)
    }
    
    func imageFromLabel(text: String, font: UIFont, textColor: UIColor, backgroundColor: UIColor, size: CGSize) -> UIImage? {
        var generatedImage: UIImage?
        
        // Must be on the main thread to do UIKit drawing
        DispatchQueue.main.sync {
            let label = UILabel(frame: CGRect(origin: .zero, size: size))
            label.backgroundColor = backgroundColor
            label.textColor = textColor
            label.font = font
            label.textAlignment = .center
            label.text = text
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else { return }
            label.layer.render(in: context)
            generatedImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        return generatedImage
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


