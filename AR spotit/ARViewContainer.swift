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

        // MARK: - ARSCNViewDelegate Methods

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            if let anchorName = anchor.name {
                print("Visualizing anchor with name: \(anchorName)")
                
                // Create a simple visual representation (e.g., a red sphere)
                let sphereGeometry = SCNSphere(radius: 0.05) // Adjust size as needed
                sphereGeometry.firstMaterial?.diffuse.contents = UIColor.red
                
                let sphereNode = SCNNode(geometry: sphereGeometry)
                sphereNode.position = SCNVector3(0, 0, 0) // Position relative to the anchor
                
                // Attach the sphere to the anchor's node
                node.addChildNode(sphereNode)
            } else {
                print("No name found for anchor, skipping visualization.")
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
            updateMeshGeometry(from: meshAnchor)
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
    
    
}
