//
//  SharedLinkModel.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-25.
//


import Foundation

struct SharedLinkModel: Identifiable, Codable {
    let id: UUID
    let shareURL: URL
    let roomName: String
    let ownerName: String
    let snapshotFileName: String?  // saved file name in Application Support
    let dateReceived: Date
    
    // Computed property to get the file URL for the snapshot image.
    var snapshotURL: URL? {
        guard let fileName = snapshotFileName else { return nil }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }
}