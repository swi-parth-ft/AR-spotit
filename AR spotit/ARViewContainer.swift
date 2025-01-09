import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @Binding var anchorName: String
    @ObservedObject var worldManager: WorldManager

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
        sceneView.debugOptions = [.showFeaturePoints]

        // 4. Add tap gesture for placing anchors
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        sceneView.addGestureRecognizer(tapGesture)

        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No dynamic updates needed for this example
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, worldManager: worldManager)
    }

    
    
    
    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var worldManager: WorldManager
        private var mergedMeshNode = SCNNode() // Merged mesh node for all anchors
        private var lastUpdateTime: Date = Date() // Throttle updates
        private let maxGuideAnchors = 50  // Set maximum number of guide anchors allowed
             var placedGuideAnchors: [(transform: simd_float4x4, anchor: ARAnchor)] = []
        private var anchorGrid: [Int: [ARAnchor]] = [:]
               private let gridSize: Float = 1.0
        var worldIsLoaded: Bool = false
        private var duplicateDistanceThreshold: Float = 1

         var processedPlaneAnchorIDs: Set<UUID> = []
        init(_ parent: ARViewContainer, worldManager: WorldManager) {
            self.parent = parent
            self.worldManager = worldManager
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
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
        }

       

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

               
               if let planeAnchor = anchor as? ARPlaneAnchor {
                   
                   
                   adjustMaxGuideAnchors(basedOn: planeAnchor)
                                   addGuideAnchorIfNeeded(newTransform: planeAnchor.transform)
                   

               }
                
                // Visualization logic for guide anchors
                if let anchorName = anchor.name, anchorName == "guide" {
                    // Your existing visualization code for debugging guide anchors
                    let guideGeometry = SCNSphere(radius: 0.01)
                    guideGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(1.0)
                    let guideNode = SCNNode(geometry: guideGeometry)
                    node.addChildNode(guideNode)

                   
                    
                    print("Visualizing guide anchor at position: \(anchor.transform.columns.3)")
                    return
                }
            
            guard let anchorName = anchor.name else {
                print("No name found for anchor, skipping visualization.")
                return
            }
            
       
            
            print("Visualizing anchor with name: \(anchorName)")
            
            let emoji = parent.extractEmoji(from: anchorName)
            var sphereGeometry: SCNSphere!
            if let emoji = emoji {
                // If an emoji is present, create a flat plane with the emoji.
                let emojiFont = UIFont.systemFont(ofSize: 100)
                let emojiSize = CGSize(width: 100, height: 100)
                guard let emojiImage = parent.imageFromLabel(text: emoji, font: emojiFont, textColor: .black, backgroundColor: .clear, size: emojiSize) else {
                    print("Failed to create emoji image.")
                    return
                }
                
                // Create a flat plane geometry for the emoji.
                let planeSize: CGFloat = 0.1  // Adjust size as needed
                let emojiPlane = SCNPlane(width: planeSize, height: planeSize)
                let emojiMaterial = SCNMaterial()
                emojiMaterial.diffuse.contents = emojiImage
                emojiMaterial.isDoubleSided = true
                emojiPlane.materials = [emojiMaterial]
                
                let emojiNode = SCNNode(geometry: emojiPlane)
                
                // Position the emoji plane at the anchor's position.
                // Adjust the y-offset if you want it above the ground.
                emojiNode.position = SCNVector3(0, 0, 0)
                
                // Optionally add a billboard constraint so the emoji always faces the camera.
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .Y
                emojiNode.constraints = [billboardConstraint]
                
                node.addChildNode(emojiNode)
            } else {
                sphereGeometry = SCNSphere(radius: 0.05)
                    sphereGeometry.firstMaterial?.diffuse.contents = UIColor.red
                    let sphereNode = SCNNode(geometry: sphereGeometry)
                    node.addChildNode(sphereNode)
            }
            
            // 2. Create a frosted glass-like rounded panel above the sphere
            let panelWidth: CGFloat = 0.3
            let panelHeight: CGFloat = 0.1
            let cornerRadius: CGFloat = 0.02
            let extrusionDepth: CGFloat = 0.01

            // Create a centered rounded rectangle bezier path
            let rect = CGRect(x: -panelWidth/2, y: -panelHeight/2, width: panelWidth, height: panelHeight)
            let roundedRectPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

            let panelGeometry = SCNShape(path: roundedRectPath, extrusionDepth: extrusionDepth)
            let panelMaterial = SCNMaterial()
            panelMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.6)
            panelMaterial.isDoubleSided = true
            panelGeometry.materials = [panelMaterial]

            let panelNode = SCNNode(geometry: panelGeometry)

            // Position the panel directly above the sphere, centered horizontally
            let verticalOffset: Float = 0.15
            let radius = sphereGeometry?.radius ?? 0.05  // Use sphereGeometry's radius if available, otherwise default
            panelNode.position = SCNVector3(0, Float(radius) + verticalOffset, 0)
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .Y
            panelNode.constraints = [billboardConstraint]

            node.addChildNode(panelNode)
            
            // 3. Render anchor name and emoji to an image
            let cleanAnchorName = anchorName.filter { !$0.isEmoji }
            let displayString = "\(cleanAnchorName)"
          //  let displayString = "\(anchorName)"
            let font = UIFont(name: "AppleColorEmoji", size: 20) ?? UIFont.systemFont(ofSize: 50)
            let textColor = UIColor.black
            let backgroundColor = UIColor.clear  // transparent background for panel overlay
            let imageSize = CGSize(width: 200, height: 100) // adjust as needed
            guard let labelImage = parent.imageFromLabel(text: displayString, font: font, textColor: textColor, backgroundColor: backgroundColor, size: imageSize) else {
                print("Failed to create label image")
                return
            }
            
            // 4. Create an SCNPlane for displaying the text and emoji
            let textPlaneGeometry = SCNPlane(width: panelWidth, height: panelHeight)
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = labelImage
            textMaterial.isDoubleSided = true
            textPlaneGeometry.materials = [textMaterial]

            let textPlaneNode = SCNNode(geometry: textPlaneGeometry)

            // Position it on the front edge of the frosted panel using extrusion depth
            let frontOffset = Float(extrusionDepth) + 0.001  // tweak as needed
            textPlaneNode.position = SCNVector3(0, 0, frontOffset)

            panelNode.addChildNode(textPlaneNode)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }

            // Throttle updates to once every 0.5 seconds
            if Date().timeIntervalSince(lastUpdateTime) < 0.5 {
                return
            }
            lastUpdateTime = Date()

            print("Updated ARMeshAnchor with identifier: \(meshAnchor.identifier)")
        //    updateMeshGeometry(from: meshAnchor)
            
            // Extract vertices from meshAnchor
                let meshGeometry = meshAnchor.geometry
                let vertexBuffer = meshGeometry.vertices.buffer as MTLBuffer
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
                
                // Create or update the point cloud node
            let pointCloudNode = parent.createPointCloudNode(from: vertices)
                // Add point cloud to the same parent node, or manage updating existing one
                node.addChildNode(pointCloudNode)
        }

        // MARK: - Mesh Handling

        func addMeshGeometry(from meshAnchor: ARMeshAnchor) {
            let meshGeometry = createSimplifiedMeshGeometry(from: meshAnchor)
            let newNode = SCNNode(geometry: meshGeometry)
            newNode.name = meshAnchor.identifier.uuidString
            mergedMeshNode.addChildNode(newNode)

            // Add merged node to scene if not already added
            if mergedMeshNode.parent == nil {
                parent.sceneView.scene.rootNode.addChildNode(mergedMeshNode)
            }
        }

        func updateMeshGeometry(from meshAnchor: ARMeshAnchor) {
            let updatedGeometry = createSimplifiedMeshGeometry(from: meshAnchor)
            if let childNode = mergedMeshNode.childNodes.first(where: { $0.name == meshAnchor.identifier.uuidString }) {
                childNode.geometry = updatedGeometry
            } else {
                // Add new mesh node if it doesn't exist
                addMeshGeometry(from: meshAnchor)
            }
        }

        func createSimplifiedMeshGeometry(from meshAnchor: ARMeshAnchor) -> SCNGeometry {
            let meshGeometry = meshAnchor.geometry

            // Vertex data
             let vertexBuffer = meshGeometry.vertices.buffer as MTLBuffer

            let vertexSource = SCNGeometrySource(
                buffer: vertexBuffer,
                vertexFormat: .float3,
                semantic: .vertex,
                vertexCount: meshGeometry.vertices.count,
                dataOffset: meshGeometry.vertices.offset,
                dataStride: meshGeometry.vertices.stride
            )

            // Face data: Sample fewer faces for better performance
            let facesBuffer = meshGeometry.faces.buffer as MTLBuffer

            let facesPointer = facesBuffer.contents()
            let totalFaceCount = meshGeometry.faces.count
            let sampledFaceCount = min(totalFaceCount, 5000) // Limit to 5000 faces
            let indexBufferLength = sampledFaceCount * 3 * MemoryLayout<UInt16>.size

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
        
        private func extractVertices(from geometry: ARMeshGeometry) -> [SIMD3<Float>] {
                    let vertexBuffer = geometry.vertices.buffer as MTLBuffer
                    let pointer = vertexBuffer.contents()
                    var vertices: [SIMD3<Float>] = []
                    for i in 0..<geometry.vertices.count {
                        let vertexPointer = pointer.advanced(by: i * geometry.vertices.stride + geometry.vertices.offset)
                        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                        vertices.append(vertex)
                    }
                    return vertices
                }

                private func gridIndex(for position: SIMD3<Float>) -> Int {
                    let x = Int(floor(position.x / gridSize))
                    let z = Int(floor(position.z / gridSize))
                    return x * 10_000 + z
                }

        private func addGuideAnchorIfNeeded(newTransform: simd_float4x4) {
            let gridIndex = gridIndex(for: SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z))
            let nearbyAnchors = anchorGrid[gridIndex] ?? []

            let alreadyPlaced = nearbyAnchors.contains { existing in
                let distance = simd_distance(existing.transform.columns.3, newTransform.columns.3)
                return distance < 1.0
            }

            if !alreadyPlaced {
                let guideAnchor = ARAnchor(name: "guide", transform: newTransform)
                parent.sceneView.session.add(anchor: guideAnchor)
                anchorGrid[gridIndex, default: []].append(guideAnchor)
                print("Added guide anchor at \(newTransform.columns.3)")
            }
        }

                private func adjustMaxGuideAnchors(basedOn planeAnchor: ARPlaneAnchor) {
                   
                    
              
                    let area = planeAnchor.extent.x * planeAnchor.extent.z
                    print("Adjusted max guide anchors to \(Int(area * 10)) based on plane size.")
                }
    }
    
    func createPointCloudNode(from vertices: [SIMD3<Float>]) -> SCNNode {
        // Create geometry source from vertex array
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
        
        // Create indices for each vertex for point drawing
        var indices = [Int32](0..<Int32(vertices.count))
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<Int32>.size)
        
        // Create a geometry element with .point primitive type
        let pointElement = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        // Create material for points
        let pointMaterial = SCNMaterial()
        pointMaterial.diffuse.contents = UIColor.white
        pointMaterial.lightingModel = .constant
      //  pointMaterial.pointSize = 3.0  // Adjust size as needed
        pointMaterial.isDoubleSided = true

        // Assemble geometry with one material
        let geometry = SCNGeometry(sources: [vertexSource], elements: [pointElement])
        geometry.materials = [pointMaterial]

        return SCNNode(geometry: geometry)
    }
    
    func imageFromLabel(text: String, font: UIFont, textColor: UIColor, backgroundColor: UIColor, size: CGSize) -> UIImage? {
        var generatedImage: UIImage?
        
        // Ensure UI operations are done on the main thread
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
        // Split the string into components separated by spaces.
        let components = string.split(separator: " ")
        // Look for a component that contains an emoji.
        for component in components.reversed() {
            if String(component).containsEmoji {
                return String(component)
            }
        }
        return nil
    }
    
    
}

extension String {
    // Simple check to see if a string contains an emoji character.
    var containsEmoji: Bool {
        return unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }
    
   
}

extension Character {
    // Check if a character is an emoji by examining its first scalar.
    var isEmoji: Bool {
        // If the character has at least one Unicode scalar, check its emoji property.
        return self.unicodeScalars.first?.properties.isEmojiPresentation ?? false
    }
}
