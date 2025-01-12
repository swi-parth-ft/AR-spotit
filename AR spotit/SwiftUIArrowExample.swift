//
//  SwiftUIArrowExample.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-11.
//

import SwiftUI
import SceneKit

struct SwiftUIArrowExample: View {
    /// The current angle (in radians) for the arrow to rotate around Y.
    @State private var arrowAngleY: Float = 0.0

    var body: some View {
        VStack(spacing: 20) {
            Text("SceneKit Arrow in SwiftUI")
                .font(.title)
            
            // The 3D arrow view
            SceneKitArrowView(arrowAngleY: $arrowAngleY)
                //.scaleEffect(0.5)
                .frame(width: 400, height: 400)
                
                // ^ Adjust as you like. This is just the size of the View container.
            
            // Slider to rotate arrow from 0..2π
            Slider(value: Binding(
                get: { Double(arrowAngleY) },
                set: { arrowAngleY = Float($0) }
            ), in: 0...(2 * Double.pi))
            .padding()
            
            Text("Arrow Y rotation: \(arrowAngleY, specifier: "%.2f") radians")
                .font(.caption)
        }
        .padding()
    }
}

struct SceneKitArrowView: UIViewRepresentable {
    @Binding var arrowAngleY: Float

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        
        // A plain Scene with default lighting
        scnView.scene = SCNScene()
        scnView.autoenablesDefaultLighting = true
        
        // Transparent background if you want to overlay on something else
        scnView.backgroundColor = .clear
        scnView.isOpaque = false
        
        // Create the arrow node, place it in front of the camera
        let arrowNode = createArrowNode()
        arrowNode.position = SCNVector3(0, 0, -0.5) // only half a meter away
        scnView.scene?.rootNode.addChildNode(arrowNode)
        
        context.coordinator.arrowNode = arrowNode
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Base rotation: -90° around X to lay arrow horizontal.
        // Then apply arrowAngleY around Y. You can tweak the base rotation further if you like.
        let baseXRotation = -Float.pi / 2 + 0.1
        context.coordinator.arrowNode?.eulerAngles = SCNVector3(baseXRotation, arrowAngleY, 0)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject {
        var arrowNode: SCNNode?
    }
    
    /// Build a smaller arrow geometry along the +Y axis
    private func createArrowNode() -> SCNNode {
        // 1) A very small cylinder (shaft)
        let cylinder = SCNCylinder(radius: 0.005, height: 0.01)
        cylinder.firstMaterial?.diffuse.contents = UIColor.blue
        let shaftNode = SCNNode(geometry: cylinder)
        // Shift its bottom to origin
        shaftNode.position = SCNVector3(0, 0.01, 0)

        // 2) A very small cone (head)
        let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.015, height: 0.05)
        cone.firstMaterial?.diffuse.contents = UIColor.blue
        let headNode = SCNNode(geometry: cone)
        // Place it atop the shaft
        headNode.position = SCNVector3(0, 0.1 + 0.025, 0)

        // 3) Combine under a parent node
        let arrowParentNode = SCNNode()
        arrowParentNode.addChildNode(shaftNode)
        arrowParentNode.addChildNode(headNode)
        
        // 4) Also scale the entire arrow smaller if you want
        arrowParentNode.scale = SCNVector3(0.5, 0.5, 0.5) // 50% smaller again

        return arrowParentNode
    }
}

// MARK: - Preview

struct SwiftUIArrowExample_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIArrowExample()
    }
}
