//
//  AddNewRoom.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-06.
//

import SwiftUI

struct AddNewRoom: View {
    @Binding var roomName: String
    @State private var selectedWorld: WorldModel?
    @State private var isShowingGuide: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    var onTapAddRoom: (() -> Void)
    
    var body: some View {
        NavigationStack {
            ZStack {

                
                VStack(alignment: .leading) {
                    
                    
                    Spacer()
                    
                    Text("Start with naming your area. e.g. Bedroom, Library 2nd floor, etc")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal)
                    TextField("Name", text: $roomName)
                        .focused($isTextFieldFocused)
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
                        roomName = roomName.trimmingTrailingWhitespace
                            onTapAddRoom()
                        dismiss()
                        //selectedWorld = WorldModel(name: roomName)
                    } label: {
                        Text("Next")
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
                .onAppear {
                    roomName = ""
                }
                .navigationTitle("New Area")
                .sheet(isPresented: $isShowingGuide) {
                    ARViewGuideView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingGuide.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            roomName = ""
                            
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
}

#Preview {
    AddNewRoom(roomName: .constant(" "), onTapAddRoom: {
        
    })
}
