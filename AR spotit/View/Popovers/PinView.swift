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
    var onCompletion: (() -> Void)? // Completion handler

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Spacer()
              
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(.title2, design: .rounded))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.green, .primary)
                        Text(isChecking ? "Your collaboration Key for \(roomName)" : "Set your Key for \(roomName) collaboration, Please note that this key can not be changed later, you will need to recollaborate to set new key. \n \nYou can view your Key anytime in the App.")
                            .font(.system(.headline, design: .rounded))

                    }
        
                 
                }
                .padding()
                if isChecking {
                    Text(pin)
                        .font(.system(.largeTitle, design: .rounded))
                        .bold()
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal)
               
                } else {
                    TextField("Key", text: $pin)
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
                        AppState.shared.isCreatingLink = true
                      //  WorldManager.shared.loadSavedWorlds {
                            if let index = WorldManager.shared.savedWorlds.firstIndex(where: { $0.name == roomName }) {
                                // Update existing world
                                WorldManager.shared.savedWorlds[index].pin = pin
                                WorldManager.shared.saveWorldList()
                            }
                            
                            dismiss()
                            onCompletion?() 

                      //  }
                    }
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
            .padding(.bottom)
            .navigationTitle(isChecking ? "Key for \(roomName)" : "Set Key")
            .sheet(isPresented: $isShowingGuide) {
                CollaborationGuideView()
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
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                
            }
           
        }
    }
}

#Preview {
    PinView(roomName: "Bedroom", pin: .constant("1234"), isChecking: false)
}
