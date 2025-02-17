//
//  PinView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-17.
//

import SwiftUI

struct PinView: View {
    var roomName: String
    @State private var selectedWorld: WorldModel?
    @State private var isShowingGuide: Bool = false
    @Binding var pin: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    var isChecking: Bool
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text(isChecking ? "Your current collaboration PIN for \(roomName)" : "Set you PIN for \(roomName) collaboration")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                if isChecking {
                    Text(pin)
                        .font(.system(.largeTitle, design: .rounded))
                        .bold()
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal)
               
                } else {
                    TextField("PIN", text: $pin)
                        .focused($isTextFieldFocused)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .padding()
                        .frame(height: 55)
                        .background(Color.secondary.opacity(0.4))
                        .cornerRadius(10)
                        .tint(.primary)
                        .padding(.horizontal)
                        .onAppear {
                            if !isChecking {
                                isTextFieldFocused = true
                            }
                        }
                }
                Button {
                    if isChecking {
                        dismiss()
                    } else {
                        WorldManager.shared.loadSavedWorlds {
                            if let index = WorldManager.shared.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                                // Update existing world
                                WorldManager.shared.savedWorlds[index].pin = pin
                                WorldManager.shared.saveWorldList()
                            }
                            
                            dismiss()
                            
                        }
                    }
                    //selectedWorld = WorldModel(name: roomName)
                } label: {
                    Text(isChecking ? "Done" : "Next")
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
//            .onAppear {
//                if !isChecking {
//                       pin = ""
//                   }
//            }
            .navigationTitle(isChecking ? "Current PIN" : "Set PIN")
            .sheet(isPresented: $isShowingGuide) {
                RoomScanGuideView()
            }
            .toolbar {
          
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        pin = ""

                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                
            }
           
        }
    }
}

