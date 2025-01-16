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
    @Binding var worldName: String
    @ObservedObject var worldManager: WorldManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
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
                    .padding(.horizontal)
                
                Button {
                    worldManager.renameWorld(currentName: worldName, newName: newName) {
                       
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


