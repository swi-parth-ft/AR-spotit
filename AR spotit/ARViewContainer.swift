import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @ObservedObject var worldManager: WorldManager
    
    func makeUIView(context: Context) -> ARSCNView {
        // Configure the ARSCNView
        sceneView.delegate = context.coordinator
        sceneView.session.run(ARWorldTrackingConfiguration())
        sceneView.automaticallyUpdatesLighting = true
        
        // Add tap gesture recognizer for placing anchors
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No need to update anything dynamically in this case
    }
    
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
        
        // Handle taps to place anchors
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            let sceneView = parent.sceneView // Directly access without unwrapping
            let location = sender.location(in: sceneView)
            
            // Perform a hit test on the sceneView to find a surface
            let hitTestResults = sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane])
            guard let result = hitTestResults.first else { return }
            
            // Create and add an anchor at the hit location
            let anchor = ARAnchor(name: "placedAnchor", transform: result.worldTransform)
            sceneView.session.add(anchor: anchor)
        }
        // ARSCNViewDelegate method to render nodes for anchors
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            if anchor.name == "placedAnchor" {
                // Create a cube node for the anchor
                let size: CGFloat = 0.05
                let cube = SCNBox(width: size, height: size, length: size, chamferRadius: 0)
                cube.firstMaterial?.diffuse.contents = UIColor.systemBlue
                
                let node = SCNNode(geometry: cube)
                
                // Add a spinning animation to the cube
                let spin = CABasicAnimation(keyPath: "rotation")
                spin.fromValue = SCNVector4(0, 1, 0, 0)
                spin.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
                spin.duration = 3
                spin.repeatCount = .infinity
                node.addAnimation(spin, forKey: "spinAnimation")
                
                return node
            }
            return nil
        }
    }
}
