//
//  AddNewRoom.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-06.
//

import SwiftUI

struct AddNewRoom: View {
    @State private var roomName = ""
    @State private var selectedWorld: WorldModel?
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Room name", text: $roomName)
                    .padding()
                    .frame(height: 55)
                    .background(Color.secondary.opacity(0.4))
                    .cornerRadius(10)
                    .padding()
                
                Button {
                    selectedWorld = WorldModel(name: roomName)
                } label: {
                    Text("Add Room")
                        .padding()
                        .frame(height: 55)
                        .background(Color.blue.opacity(0.4))
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Add Room")
            .sheet(item: $selectedWorld) { world in
                ContentView(currentRoomName: world.name, directLoading: false, findAnchor: .constant(""))
            }
        }
    }
}

#Preview {
    AddNewRoom()
}
