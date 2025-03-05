import SwiftUI

struct EditAnchorView: View {
    @Binding var anchorName: String
    @State private var newName = ""
    @Environment(\.dismiss) var dismiss
    @State private var isSelectingEmoji = false
    @Environment(\.colorScheme) var colorScheme
    @State private var emoji: String = ""
    @State private var isRenaming = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedEmoji: EmojiDetails? = {
          let emojis = loadEmojis()
          return emojis.first { $0.id == "🎣" }
      }()
    let onDelete: (String) -> Void  // 1️⃣
    let onMove: (String) -> Void
    let onRename: (String, String) -> Void
    
    
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
                .onAppear {
                    let emojis = loadEmojis()
                    let currentEmojiId = extractEmoji(from: anchorName) ?? "🎣"
                 
                    selectedEmoji = emojis.first { $0.id == currentEmojiId }
                }
                .padding()
                .sheet(isPresented: $isSelectingEmoji) {
                    EmojiPickerView(selectedEmoji: $selectedEmoji)
                }
                
                Text("Rename you item with new name or new emoji. e.g. fishing rod 🎣")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                
                if isRenaming {
                    HStack {
                        
                        
                        TextField("Enter New Name", text: $newName)
                            .focused($isTextFieldFocused)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                            .padding()
                            .frame(height: 55)
                            .background(Color.secondary.opacity(0.4))
                            .cornerRadius(10)
                            .tint(.primary)
                            .onAppear {
                                        isTextFieldFocused = true
                                    }
                        
                        
                        Button {
                            newName = "\(newName.trimmingTrailingWhitespace) \(selectedEmoji?.id ?? "🏴‍☠️")"
                            
                            onRename(anchorName, newName)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .frame(width: 55, height: 55)
                                .background(Color.secondary.opacity(0.4))
                                .cornerRadius(30)
                        }
                        
                        Button {
                            withAnimation {
                                isRenaming.toggle()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .frame(width: 55, height: 55)
                                .background(Color.secondary.opacity(0.4))
                                .cornerRadius(30)
                            
                        }
                        
                        
                    }
                    .padding(.horizontal)
                    
                } else {
                    
                    
                    Button {
                        withAnimation {
                            isRenaming.toggle()
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
                Button {
                    onMove(anchorName)
                } label: {
                    Text("Move to new location")
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
                
                Button {
                    onDelete(anchorName)
                } label: {
                    Text("Delete")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.red)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary.opacity(1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                

            }
            
            .navigationTitle("Edit \(anchorName)")
            .navigationBarTitleDisplayMode(.inline)
            .padding()
        }
    }
}
