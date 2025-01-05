import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @Binding var anchorName: String
    @ObservedObject var worldManager: WorldManager

    func makeUIView(context: Context) -> ARSCNView {
        sceneView.delegate = context.coordinator
        sceneView.session.run(ARWorldTrackingConfiguration())
        sceneView.automaticallyUpdatesLighting = true

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        sceneView.addGestureRecognizer(tapGesture)

        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, worldManager: worldManager)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var worldManager: WorldManager

        init(_ parent: ARViewContainer, worldManager: WorldManager) {
            self.parent = parent
            self.worldManager = worldManager
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            let sceneView = parent.sceneView
            let location = sender.location(in: sceneView)

            let hitTestResults = sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane])
            guard let result = hitTestResults.first else { return }

            let name = parent.anchorName.isEmpty ? "defaultAnchor" : parent.anchorName
            let anchor = ARAnchor(name: name, transform: result.worldTransform)
            sceneView.session.add(anchor: anchor)

            print("Placed anchor with name: \(name)")
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let anchorName = anchor.name else { return nil }

            let parentNode = SCNNode()
            let cube = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
            cube.firstMaterial?.diffuse.contents = UIColor.systemBlue
            let cubeNode = SCNNode(geometry: cube)

            let textGeometry = SCNText(string: anchorName, extrusionDepth: 0.5)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            let textNode = SCNNode(geometry: textGeometry)
            textNode.scale = SCNVector3(0.0015, 0.0015, 0.0015)
            textNode.position = SCNVector3(0, 0.06, 0)

            parentNode.addChildNode(cubeNode)
            parentNode.addChildNode(textNode)
            return parentNode
        }
    }
}
