//
//  CanNotModifyAnchorView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-25.
//

import SwiftUI

struct CanNotModifyAnchorView: View {
    @Binding var anchorName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var emoji: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedEmoji: EmojiDetails? = {
          let emojis = loadEmojis()
          return emojis.first { $0.id == "🎣" }
      }()
 
    var owner = AppState.shared.ownerName
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
                if char.isEmoji {
                    return String(char)
                }
            }
            return nil
    }
    
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                
                
                HStack {
                    Spacer()
                    Button {
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
                .onAppear {
                    let emojis = loadEmojis()
                    let currentEmojiId = extractEmoji(from: anchorName) ?? "🎣"
                 
                    selectedEmoji = emojis.first { $0.id == currentEmojiId }
                }
                .padding()
          
                
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    
                    Text("The item \(anchorName) cannot be modified; it is integrated into the map by \(owner). Ask \(owner) to modify it.")

                        .font(.system(.headline, design: .rounded))
                    
                }
                .padding(.horizontal)
                
              
                Button {
                    dismiss()
                } label: {
                    Text("Okay")
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
            .navigationTitle("Can't edit \(anchorName)")
            .padding()
        }
    }
}

#Preview {
    CanNotModifyAnchorView(anchorName: .constant("test"))
}
