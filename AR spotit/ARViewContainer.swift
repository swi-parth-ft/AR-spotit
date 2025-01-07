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

        init(_ parent: ARViewContainer, worldManager: WorldManager) {
            self.parent = parent
            self.worldManager = worldManager
        }

        // MARK: - Tap to Place Anchor

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            let sceneView = parent.sceneView
            let location = sender.location(in: sceneView)

            // Perform a hit test against feature points or an estimated horizontal plane
            let hitTestResults = sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane])
            guard let result = hitTestResults.first else { return }

            // If anchorName is empty, default to "defaultAnchor"
            let name = parent.anchorName.isEmpty ? "defaultAnchor" : parent.anchorName
            let anchor = ARAnchor(name: name, transform: result.worldTransform)
            sceneView.session.add(anchor: anchor)

            print("Placed anchor with name: \(name)")
        }

       

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let anchorName = anchor.name else {
                print("No name found for anchor, skipping visualization.")
                return
            }
            
            print("Visualizing anchor with name: \(anchorName)")
            
            // 1. Create a red sphere to represent the anchor
            let sphereGeometry = SCNSphere(radius: 0.05)
            sphereGeometry.firstMaterial?.diffuse.contents = UIColor.red
            let sphereNode = SCNNode(geometry: sphereGeometry)
            node.addChildNode(sphereNode)
            
            // 2. Create a frosted glass-like panel above the sphere
            let panelWidth: CGFloat = 0.2
            let panelHeight: CGFloat = 0.1
            let panelGeometry = SCNPlane(width: panelWidth, height: panelHeight)
            let panelMaterial = SCNMaterial()
            panelMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.5)
            panelMaterial.isDoubleSided = true
            panelGeometry.materials = [panelMaterial]
            
            let panelNode = SCNNode(geometry: panelGeometry)
            let verticalOffset: Float = 0.15
            panelNode.position = SCNVector3(0, Float(sphereGeometry.radius) + verticalOffset, 0)
            
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .Y
            panelNode.constraints = [billboardConstraint]
            node.addChildNode(panelNode)
            
            // 3. Render anchor name and emoji to an image
            let displayString = "\(anchorName) ✨"
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
            // Position it exactly over the frosted panel (same position)
            textPlaneNode.position = SCNVector3(0, 0, 0.001) // slight z-offset to avoid z-fighting
            
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
                guard let vertexBuffer = meshGeometry.vertices.buffer as? MTLBuffer else { return }
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
            guard let vertexBuffer = meshGeometry.vertices.buffer as? MTLBuffer else {
                print("Failed to get vertex buffer")
                return SCNGeometry()
            }

            let vertexSource = SCNGeometrySource(
                buffer: vertexBuffer,
                vertexFormat: .float3,
                semantic: .vertex,
                vertexCount: meshGeometry.vertices.count,
                dataOffset: meshGeometry.vertices.offset,
                dataStride: meshGeometry.vertices.stride
            )

            // Face data: Sample fewer faces for better performance
            guard let facesBuffer = meshGeometry.faces.buffer as? MTLBuffer else {
                print("Failed to get faces buffer")
                return SCNGeometry()
            }

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
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        label.layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    
}
