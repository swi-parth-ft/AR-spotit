//
//  ARMesh.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-18.
//

import SwiftUI
import ARKit
import CoreHaptics
import Drops
import AVFoundation
import CloudKit

// MARK: - Helper functions for point clouds
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
    
    
}



extension ARViewContainer.Coordinator {
    //MARK: Mesh functions
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
}
