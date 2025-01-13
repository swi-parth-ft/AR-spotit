import SwiftUI
import ARKit
import CoreHaptics


struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @Binding var anchorName: String
    @ObservedObject var worldManager: WorldManager
    var findAnchor: String
    func makeUIView(context: Context) -> ARSCNView {
        sceneView.delegate = context.coordinator
        
        // 1. Create an ARWorldTrackingConfiguration
        let configuration = ARWorldTrackingConfiguration()
        
        // 2. Enable LiDAR-based scene reconstruction if available
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.sceneReconstruction = .mesh
            configuration.frameSemantics.insert(.sceneDepth)
            print("Scene reconstruction with LiDAR enabled.")
        } else {
            print("LiDAR-based scene reconstruction is not supported on this device.")
        }
        
        // Enable plane detection for better context
        configuration.planeDetection = [.horizontal, .vertical]
        
        // 3. Run the session with this configuration
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session.delegate = context.coordinator as? any ARSessionDelegate
        // 4. Add tap gesture for placing anchors
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        sceneView.addGestureRecognizer(tapGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.updateNodeVisibility(in: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, worldManager: worldManager)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate, Sendable {
        
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
        
        // For scanning coverage logic
        private var relocalizationTask: Task<Void, Never>?
        private var zoneEntryTimes: [String: Date] = [:]
        
        // Arrow references
        private var currentArrowNode: SCNNode?
        
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
                
                /// Recursively check node names and show/hide them based on `isShowingAll` & `findAnchor`.
                private func refreshVisibilityRecursive(node: SCNNode) {
                    // If the ARKit anchor's name is stored in `node.name`, we can rely on it here.
                    guard let nodeName = node.name else {
                        // Recur into children anyway, in case sub-nodes have meaningful names
                        for child in node.childNodes {
                            refreshVisibilityRecursive(node: child)
                        }
                        return
                    }
                    
                    // Decide if hidden or not:
                    // - If isShowingAll == true => always show
                    // - If isShowingAll == false => only show if nodeName == findAnchor
                    let shouldHide = !worldManager.isShowingAll && nodeName != parent.findAnchor
                    node.isHidden = shouldHide
                    
                    // Also apply recursively to children
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
        // MARK: - Tap for anchors
        
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
            }
        }
        
        // MARK: - Define scanning “zones”
        
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
                } else if !worldManager.scannedZones.contains(zoneName) {
                    // If not scanned yet, show arrow pointing to that zone
//                    if currentArrowNode == nil {
//                        placeArrowInFrontOfCamera(targetPosition: zonePosition)
//                    } else {
//                        ensureArrowInView(currentArrowNode!, targetPosition: zonePosition)
//                    }
                }
            }
        }
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            let anchorPosition = SIMD3<Float>(anchor.transform.columns.3.x,
                                              anchor.transform.columns.3.y,
                                              anchor.transform.columns.3.z)
            checkZoneCoverage(for: anchorPosition)
            
            if let planeAnchor = anchor as? ARPlaneAnchor {
                adjustMaxGuideAnchors(basedOn: planeAnchor)
                addGuideAnchorIfNeeded(newTransform: planeAnchor.transform)
            }
//            
//            if !parent.worldManager.isShowingAll {
//                  // If isShowingAll == false, skip everything unless anchor.name matches `findAnchor`.
//                  guard let anchorName = anchor.name, anchorName == parent.findAnchor else {
//                      print("Skipping anchor \(anchor.name ?? "nil") since isShowingAll == false and it's not findAnchor.")
//                      return
//                  }
//              }
            
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
                // If an emoji is present, create a flat plane with the emoji
                let emojiFont = UIFont.systemFont(ofSize: 100)
                let emojiSize = CGSize(width: 100, height: 100)
                guard let emojiImage = parent.imageFromLabel(
                    text: emoji,
                    font: emojiFont,
                    textColor: .black,
                    backgroundColor: .clear,
                    size: emojiSize
                ) else {
                    print("Failed to create emoji image.")
                    return
                }
                
                let planeSize: CGFloat = 0.1
                let emojiPlane = SCNPlane(width: planeSize, height: planeSize)
                let emojiMaterial = SCNMaterial()
                emojiMaterial.diffuse.contents = emojiImage
                emojiMaterial.isDoubleSided = true
                emojiPlane.materials = [emojiMaterial]
                
                let emojiNode = SCNNode(geometry: emojiPlane)
                emojiNode.position = SCNVector3(0, 0, 0)
                
                // Make it face the camera
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .Y
                emojiNode.constraints = [billboardConstraint]
                
                node.addChildNode(emojiNode)
            } else {
                let sphereGeometry = SCNSphere(radius: 0.03)
                sphereGeometry.firstMaterial?.diffuse.contents = UIColor.white
                let sphereNode = SCNNode(geometry: sphereGeometry)
                node.addChildNode(sphereNode)
            }
            
            // 2) “Frosted glass” panel above
            let panelWidth: CGFloat = 0.3
            let panelHeight: CGFloat = 0.1
            let cornerRadius: CGFloat = 0.02
            let extrusionDepth: CGFloat = 0.01
            
            let rect = CGRect(x: -panelWidth/2, y: -panelHeight/2, width: panelWidth, height: panelHeight)
            let roundedRectPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            
            let panelGeometry = SCNShape(path: roundedRectPath, extrusionDepth: extrusionDepth)
            let panelMaterial = SCNMaterial()
            panelMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.6)
            panelMaterial.isDoubleSided = true
            panelGeometry.materials = [panelMaterial]
            
            let panelNode = SCNNode(geometry: panelGeometry)
            let verticalOffset: Float = 0.15
            panelNode.position = SCNVector3(0, 0.05 + verticalOffset, 0)
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .Y
            panelNode.constraints = [billboardConstraint]
            node.addChildNode(panelNode)
            
            // 3) Text plane
            let cleanAnchorName = anchorName.filter { !$0.isEmoji }
            let displayString = "\(cleanAnchorName)"
            let font = UIFont(name: "AppleColorEmoji", size: 20) ?? UIFont.systemFont(ofSize: 50)
            let imageSize = CGSize(width: 200, height: 100)
            guard let labelImage = parent.imageFromLabel(
                text: displayString,
                font: font,
                textColor: .black,
                backgroundColor: .clear,
                size: imageSize
            ) else {
                print("Failed to create label image")
                return
            }
            
            let textPlaneGeometry = SCNPlane(width: panelWidth, height: panelHeight)
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = labelImage
            textMaterial.isDoubleSided = true
            textPlaneGeometry.materials = [textMaterial]
            
            let textPlaneNode = SCNNode(geometry: textPlaneGeometry)
            textPlaneNode.position = SCNVector3(0, 0, extrusionDepth + 0.001)
            panelNode.addChildNode(textPlaneNode)
            
            print(parent.findAnchor)
            if anchorName == parent.findAnchor {
                        addJumpingAnimation(to: node)
                    }
            
            if !worldManager.isShowingAll {
                let shouldHide = !worldManager.isShowingAll && anchorName != parent.findAnchor
                node.isHidden = shouldHide
            }
        }
        
//        func session(_ session: ARSession, didUpdate frame: ARFrame) {
//                guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == parent.findAnchor }) else {
//                    print("Anchor not found.")
//                    return
//                }
//                
//                // Get the camera and anchor positions
//                let cameraTransform = frame.camera.transform
//                let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
//                let anchorPosition = SIMD3<Float>(anchor.transform.columns.3.x, anchor.transform.columns.3.y, anchor.transform.columns.3.z)
//                
//                // Calculate the distance
//                let distance = simd_distance(cameraPosition, anchorPosition)
//                print("Distance to anchor: \(distance)")
//                
//                // Trigger haptic feedback based on distance
//                provideHapticFeedback(for: distance)
//            }
        
        private func pulseInterval(for distance: Float) -> TimeInterval {
                    let maxDistance: Float = 3.0
                    let minInterval: TimeInterval = 0.1
                    let maxInterval: TimeInterval = 1.0
                    
                    // Clamp distance to [0, maxDistance]
                    let clampedDist = max(0, min(distance, maxDistance))
                    // fraction = 0.0 (very close) -> 1.0 (very far)
                    let fraction = clampedDist / maxDistance
                    
                    // Lerp interval between 0.1s and 1.0s
                    // fraction=1 => interval=1.0  (far)
                    // fraction=0 => interval=0.1  (close)
            let interval = minInterval + (maxInterval - minInterval) * Double(fraction)
                    return interval
                }
                
                private func playDub() {
                    guard let hapticEngine = hapticEngine else { return }
                    
                    // Use a short transient “thump”
                    // If you like, you can vary intensity as well
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
                
                // MARK: - ARSessionDelegate: Called every frame
                func session(_ session: ARSession, didUpdate frame: ARFrame) {
                    
                    // Look for the anchor you want to track
                    guard let anchor = session.currentFrame?.anchors.first(where: {
                        $0.name == parent.findAnchor
                    }) else {
                        // If you never find the anchor, no dubs
                        print("Anchor not found.")
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
                    
                    // Turn distance into a pulsing interval
                    let interval = pulseInterval(for: distance)
                    
                    // If it's time to do the next "dub," do it and set the next time
                    if Date() >= nextPulseTime {
                        playDub()
                        nextPulseTime = Date().addingTimeInterval(interval)
                    }
                }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            
            // Throttle updates to once every 0.5 seconds
            if Date().timeIntervalSince(lastUpdateTime) < 0.5 {
                return
            }
            lastUpdateTime = Date()
           
            print("Updated ARMeshAnchor with identifier: \(meshAnchor.identifier)")
            
            // Optionally, you can update or merge the mesh geometry here if you wish.
            // We'll just demonstrate extracting the vertices into a point cloud.
            
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
        
        // MARK: - Mesh Handling
        
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
        
        // MARK: - Plane Anchors & “Guide” anchors
        
        private func addGuideAnchorIfNeeded(newTransform: simd_float4x4) {
            guard worldIsLoaded else {
                print("Skipping guide anchor placement. Relocalization not complete.")
                return
            }
            
            let position = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
            
            // Check for nearby guide anchors to avoid duplicates
            let isDuplicate = parent.sceneView.session.currentFrame?.anchors.contains(where: { anchor in
                anchor.name == "guide"
                && simd_distance(anchor.transform.columns.3, newTransform.columns.3) < 1.0
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
        
        // MARK: - Camera tracking
        
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
        
        // MARK: - The arrow logic
        
        func createArrowNode() -> SCNNode {
            // Shaft
            let cylinder = SCNCylinder(radius: 0.02, height: 0.1)
            cylinder.firstMaterial?.diffuse.contents = UIColor.red
            let shaftNode = SCNNode(geometry: cylinder)
            shaftNode.position = SCNVector3(0, 0.05, 0)
            
            // Head
            let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.04, height: 0.08)
            cone.firstMaterial?.diffuse.contents = UIColor.red
            let headNode = SCNNode(geometry: cone)
            headNode.position = SCNVector3(0, 0.14, 0)
            
            // Combine
            let arrowNode = SCNNode()
            arrowNode.addChildNode(shaftNode)
            arrowNode.addChildNode(headNode)
            
            // Rotate so arrow is along -Z by default
            arrowNode.eulerAngles.x = -.pi / 2
            
            return arrowNode
        }
        
        func placeArrowInFrontOfCamera(targetPosition: SIMD3<Float>) {
            guard let currentFrame = parent.sceneView.session.currentFrame else {
                print("No current AR frame available.")
                return
            }
            // Camera transform
            let camTransform = currentFrame.camera.transform
            let camPos = SIMD3<Float>(camTransform.columns.3.x,
                                      camTransform.columns.3.y,
                                      camTransform.columns.3.z)
            // Forward is -Z
            let forwardDir = normalize(SIMD3<Float>(-camTransform.columns.2.x,
                                                    -camTransform.columns.2.y,
                                                    -camTransform.columns.2.z))
            // Place arrow ~1m in front
            let arrowPos = camPos + (forwardDir * 1.0)
            
            let arrowNode = createArrowNode()
            arrowNode.position = SCNVector3(arrowPos.x, arrowPos.y, arrowPos.z)
            parent.sceneView.scene.rootNode.addChildNode(arrowNode)
            currentArrowNode = arrowNode
            
            // Point toward desired zone
            pointArrowToward(arrowNode, targetPosition: targetPosition)
        }
        
        func ensureArrowInView(_ arrowNode: SCNNode, targetPosition: SIMD3<Float>) {
            guard let currentFrame = parent.sceneView.session.currentFrame else { return }
            
            let cameraTransform = currentFrame.camera.transform
            let forwardDirection = normalize(SIMD3<Float>(-cameraTransform.columns.2.x,
                                                          -cameraTransform.columns.2.y,
                                                          -cameraTransform.columns.2.z))
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                              cameraTransform.columns.3.y,
                                              cameraTransform.columns.3.z)
            let adjustedPosition = cameraPosition + (forwardDirection * 1.0)
            arrowNode.position = SCNVector3(adjustedPosition.x, adjustedPosition.y, adjustedPosition.z)
            
            pointArrowToward(arrowNode, targetPosition: targetPosition)
        }
        
        func pointArrowToward(_ arrowNode: SCNNode, targetPosition: SIMD3<Float>) {
            let arrowPosition = SIMD3<Float>(arrowNode.position.x, arrowNode.position.y, arrowNode.position.z)
            let direction = normalize(targetPosition - arrowPosition)
            
            // Build a transform that looks down negative Z = direction
            var transform = matrix_identity_float4x4
            transform.columns.2 = SIMD4<Float>(-direction.x, -direction.y, -direction.z, 0)
            // Keep Y as global up or a cross-based approach, depending on your needs:
            transform.columns.1 = SIMD4<Float>(0, 1, 0, 0)
            // Recompute X as cross(Y, Z)
            transform.columns.0 = SIMD4<Float>(
                direction.y * transform.columns.1.z - direction.z * transform.columns.1.y,
                direction.z * transform.columns.1.x - direction.x * transform.columns.1.z,
                direction.x * transform.columns.1.y - direction.y * transform.columns.1.x,
                0
            )
            transform.columns.3 = SIMD4<Float>(arrowPosition, 1)
            
            arrowNode.transform = SCNMatrix4(transform)
        }
        
        func removeArrow() {
            currentArrowNode?.removeFromParentNode()
            currentArrowNode = nil
            print("Arrow removed.")
        }
        
         func addJumpingAnimation(to node: SCNNode) {
                // Create a jumping animation
                let moveUp = SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.5)
                let moveDown = SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.5)
                let jump = SCNAction.sequence([moveUp, moveDown])
                let repeatJump = SCNAction.repeatForever(jump)
                
                // Run the animation on the node
                node.runAction(repeatJump)
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

// Simple checks for emoji
extension String {
    var containsEmoji: Bool {
        return unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }

}

extension Character {
    var isEmoji: Bool {
        return self.unicodeScalars.contains { scalar in
            scalar.properties.isEmoji ||
            (scalar.value >= 0x1F600 && scalar.value <= 0x1F64F) || // Emoticons
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F5FF) || // Misc Symbols and Pictographs
            (scalar.value >= 0x1F680 && scalar.value <= 0x1F6FF) || // Transport and Map
            (scalar.value >= 0x2600 && scalar.value <= 0x26FF) ||   // Misc Symbols
            (scalar.value >= 0x2700 && scalar.value <= 0x27BF) ||   // Dingbats
            (scalar.value >= 0xFE00 && scalar.value <= 0xFE0F) ||   // Variation Selectors
            (scalar.value >= 0x1F900 && scalar.value <= 0x1F9FF) || // Supplemental Symbols and Pictographs
            (scalar.value >= 0x1F1E6 && scalar.value <= 0x1F1FF)    // Flags
        }
    }
}

// Helper to build translation matrices
extension matrix_float4x4 {
    static func translation(_ t: SIMD3<Float>) -> matrix_float4x4 {
        var result = matrix_identity_float4x4
        result.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1.0)
        return result
    }
}
