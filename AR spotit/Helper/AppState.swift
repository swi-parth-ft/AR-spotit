//
//  AppState.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//

import Foundation
import CloudKit


class AppState: ObservableObject {
    static let shared = AppState()
    @Published var pendingShare: CKShare?
    @Published var isWorldUpdated: Bool = false
    @Published var isiCloudShare: Bool = false
    @Published var publicRecordName: String = ""
    @Published var isCreatingLink: Bool = false
    @Published var isShowingPinSheet = false
    @Published var isShowingOpenSaveSheet = false
    @Published var pendingSharedRecord: CKRecord?
    @Published var pendingAssetFileURL: URL?
    @Published var pendingRoomName: String?
    @Published var isShowingCollaborationChoiceSheet = false
    @Published var isViewOnly: Bool = false
}
