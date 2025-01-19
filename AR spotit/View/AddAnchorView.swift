//
//  AddAnchorView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-13.
//

import SwiftUI

struct AddAnchorView: View {
    
    @Binding  var anchorName: String
    @ObservedObject var worldManager: WorldManager

    @State private var emoji: String = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isSelectingEmoji = false
    @State private var selectedEmoji: EmojiDetails? = {
          let emojis = loadEmojis()
          return emojis.first { $0.id == "🎣" }
      }()
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Button {
                        isSelectingEmoji.toggle()
                    } label: {
                        Text(selectedEmoji?.id ?? "")
                            .font(.system(size: 50))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                            .padding()
                            .frame(width: 100, height: 100)
                            .background(Color.secondary.opacity(0.4))
                            .cornerRadius(50)
                            .padding(.horizontal)
                    }
                    Spacer()
                }
                .padding()
                .sheet(isPresented: $isSelectingEmoji) {
                    EmojiPickerView(selectedEmoji: $selectedEmoji)
                }
                
                Text("Start with naming your item and then select an emoji. e.g. fishing rod 🎣")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                TextField("Name", text: $anchorName)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(height: 55)
                    .background(Color.secondary.opacity(0.4))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
               
                
                Button {
                    anchorName = "\(anchorName) \(selectedEmoji?.id ?? "🏴‍☠️")"
                    worldManager.isAddingAnchor = true
                    
                    dismiss()
                } label: {
                    Text("Add")
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
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.large)

            .toolbar {
                Button {
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
    AddAnchorView(anchorName: .constant("test"), worldManager: WorldManager())
}
