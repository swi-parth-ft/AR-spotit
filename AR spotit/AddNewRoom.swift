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
    @State private var isShowingGuide: Bool = false
    @Environment(\.colorScheme) var colorScheme
    init() {
            var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle) /// the default large title font
            titleFont = UIFont(
                descriptor:
                    titleFont.fontDescriptor
                    .withDesign(.rounded)? /// make rounded
                    .withSymbolicTraits(.traitBold) /// make bold
                    ??
                    titleFont.fontDescriptor, /// return the normal title if customization failed
                size: titleFont.pointSize
            )
            
            /// set the rounded font
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
        }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Start with naming your area. e.g. Bedroom, Library 2nd floor, etc")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                TextField("Name", text: $roomName)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(height: 55)
                    .background(Color.secondary.opacity(0.4))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button {
                    selectedWorld = WorldModel(name: roomName)
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
            .navigationTitle("New Area")
            .sheet(item: $selectedWorld) { world in
                ContentView(currentRoomName: world.name, directLoading: false, findAnchor: .constant(""))
            }
            .sheet(isPresented: $isShowingGuide) {
                RoomScanGuideView()
            }
            .toolbar {
                Button {
                    isShowingGuide.toggle()
                } label: {
                    Image(systemName: "lightbulb.circle")
                        .font(.title2)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }
           
        }
    }
}

#Preview {
    AddNewRoom()
}
