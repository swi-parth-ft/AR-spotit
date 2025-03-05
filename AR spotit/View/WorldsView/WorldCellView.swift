//
//  WorldCellView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//
import SwiftUI

// MARK: - WorldCellView Subview
struct WorldCellView: View {
    let world: WorldModel
    let anchors: [String]
    let searchText: String
    let colorScheme: ColorScheme
    let animationNamespace: Namespace.ID
    let onTap: () -> Void
    let onARKitTap: () -> Void
    let onRename: () -> Void
    let onShare: () -> Void
    let onShareQR: () -> Void
    let onShowPIN: () -> Void
    let onDelete: () -> Void
    let onAnchorTap: (String) -> Void
    let filteredAnchors: [String]
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
            if char.isEmoji { return String(char) }
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                let snapshotPath = WorldModel.appSupportDirectory.appendingPathComponent("\(world.name)_snapshot.png")
                if FileManager.default.fileExists(atPath: snapshotPath.path),
                   let uiImage = UIImage(contentsOfFile: snapshotPath.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: UIDevice.isIpad ? 300 : 200)
                        .clipped()
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.0)],
                                                     startPoint: .bottom, endPoint: .top))
                        )
                        .padding(.horizontal)
                        .conditionalModifier(colorScheme != .dark) { view in
                            view.colorInvert()
                        }
                        .shadow(color: colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2), radius: 5)
                } else {
                    Text("No Snapshot")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack {
                    if world.isCollaborative {
                        HStack {
                            Spacer()
                            Image(systemName: "person.2.fill")
                                .font(.headline)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .symbolEffect(.pulse)
                        }
                        .padding(.horizontal)
                    }
                    Spacer()
                    HStack {
                        Text(world.name)
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Spacer()
                        Button(action: {
                            onARKitTap()
                        }) {
                            Image(systemName: "arkit")
                                .font(.title)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .frame(height: UIDevice.isIpad ? 300 : 200)
            .padding(.vertical, 10)
            .matchedTransitionSource(id: "zoom-\(world.name)", in: animationNamespace)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .contextMenu {
                Button {
                    onRename()
                } label: {
                    HStack {
                        Text("Rename")
                        Image(systemName: "character.cursor.ibeam")
                            .font(.title)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                Button {
                    onShare()
                } label: {
                    HStack {
                        Text("Share")
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                if world.isCollaborative {
                    Button {
                        onShareQR()
                    } label: {
                        HStack {
                            Text("Share QR code")
                            Image(systemName: "qrcode")
                                .font(.title2)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                    }
                    Button {
                        onShowPIN()
                    } label: {
                        HStack {
                            Text("Show PIN")
                            Image(systemName: "key")
                                .font(.title2)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                    }
                    .onAppear { _ = true } // Mimics isChecking = true
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack {
                        Text("Delete")
                            .foregroundColor(.red)
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            
            if !searchText.isEmpty {
                AnchorGridView(filteredAnchors: filteredAnchors, colorScheme: colorScheme, onAnchorTap: onAnchorTap)
            }
        }
    }
}
