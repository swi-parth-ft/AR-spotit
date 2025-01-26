//
//  ARWorldMapContainer.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-26.
//


import ARKit

final class ARWorldMapContainer: NSObject, NSSecureCoding {
    static var supportsSecureCoding = true
    
    let map: ARWorldMap
    let imageData: Data? // PNG or JPEG bytes
    
    init(map: ARWorldMap, imageData: Data?) {
        self.map = map
        self.imageData = imageData
        super.init()
    }
    
    required init?(coder: NSCoder) {
        guard let map = coder.decodeObject(of: ARWorldMap.self, forKey: "map")
        else { return nil }
        self.map = map
        
        self.imageData = coder.decodeObject(of: NSData.self, forKey: "imageData") as Data?
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(map, forKey: "map")
        coder.encode(imageData, forKey: "imageData")
    }
}