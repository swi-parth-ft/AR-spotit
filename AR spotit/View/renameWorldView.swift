//
//  renameWorldView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-14.
//

import SwiftUI
import Drops

struct renameWorldView: View {
    @State private var newName = ""
    @Environment(\.colorScheme) var colorScheme
     var worldName: String
    @ObservedObject var worldManager: WorldManager
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    var showWarning: Bool = false
    var newAnchors: Int = 0
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                
                if showWarning {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            
                            Text("After renaming, you’ll need to create a new collaboration link.")
                                .font(.system(.headline, design: .rounded))
                            
                        }
                        
                        if newAnchors > 0 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                
                                Text("You have \(newAnchors) new items. Please open the AR to sync them before renaming.")
                                    .font(.system(.headline, design: .rounded))
                                
                            }
                            
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                
                                Text("If you have any new items. Please open the AR to sync them before renaming.")
                                    .font(.system(.headline, design: .rounded))
                                
                            }
                        }
                    }
                    .padding()

                }
                
                Text("Rename \(worldName) to something that helps you find it better.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                TextField("New name", text: $newName)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(height: 55)
                    .background(Color.secondary.opacity(0.4))
                    .cornerRadius(10)
                    .tint(.primary)
                    .padding(.horizontal)
                    .onAppear {
                                isTextFieldFocused = true
                            }
                Button {
                    worldManager.renameWorld(currentName: worldName, newName: newName) {
                        
                        DispatchQueue.main.async {
                                AppState.shared.isWorldUpdated.toggle() // Notify WorldsView
                            }// Notify WorldsView
                        HapticManager.shared.notification(type: .success)

                        let drop = Drop.init(title: "Renamed \(worldName) to \(newName)")
                        Drops.show(drop)
                        dismiss()
                               
                    }

                } label: {
                    Text("Rename")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary.opacity(1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Rename \(worldName)")
          
            .toolbar {
                Button {
                  //  isShowingGuide.toggle()
                } label: {
                    Image(systemName: "lightbulb.circle")
                        .font(.title2)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }
//            .onChange(of: worldManager.reload) {
//                dismiss()
//            }
           
        }
    }
}


