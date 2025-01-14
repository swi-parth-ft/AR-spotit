import SwiftUI
import Foundation

struct EmojiDetails: Identifiable, Decodable {
    var id: String { emoji } // Use the emoji as the unique identifier
    var emoji: String = ""   // Will be set manually after decoding
    let name: String
    let slug: String
    let group: String
    let emojiVersion: String
    let unicodeVersion: String
    let skinToneSupport: Bool

    enum CodingKeys: String, CodingKey {
        case name, slug, group
        case emojiVersion = "emoji_version"
        case unicodeVersion = "unicode_version"
        case skinToneSupport = "skin_tone_support"
    }
}
func loadEmojis() -> [EmojiDetails] {
    
    if let resourcePath = Bundle.main.resourcePath {
        let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
        print("Files in main bundle: \(files ?? [])")
    }
    guard let url = Bundle.main.url(forResource: "emojis", withExtension: "json") else {
        print("Failed to find emojis.json")
        return []
    }

    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let rawEmojis = try decoder.decode([String: EmojiDetails].self, from: data)

        // Convert the dictionary to an array and set the emoji key as id
        return rawEmojis.map { key, value in
            var emojiDetails = value
            emojiDetails.emoji = key // Set the emoji as the id
            return emojiDetails
        }
    } catch {
        print("Failed to load and decode emojis.json: \(error)")
        return []
    }
}
struct EmojiPickerView: View {
    @State private var searchText: String = ""
    @Binding var selectedEmoji: EmojiDetails?
    let emojis: [EmojiDetails] = loadEmojis()
    @State private var groupedEmojisCache: [String: [EmojiDetails]] = [:] // Cache grouped emojis
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var groupedEmojis: [String: [EmojiDetails]] {
        if searchText.isEmpty {
            return groupedEmojisCache
        } else {
            return Dictionary(grouping: filteredEmojis, by: { $0.group })
        }
    }

    var filteredEmojis: [EmojiDetails] {
        if searchText.isEmpty {
            return emojis
        } else {
            return emojis.filter { emoji in
                emoji.name.lowercased().contains(searchText.lowercased()) ||
                emoji.group.lowercased().contains(searchText.lowercased()) ||
                emoji.slug.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    

    var body: some View {
        VStack {
            
           
            
            

         
            ZStack {
                // Emoji Grid
                ScrollView {
                    if let selectedEmoji = selectedEmoji {
                        Text(selectedEmoji.id)
                            .font(.system(size: 100)) // Large emoji display
                            .padding()
                            .shadow(color: Color(getDominantColor(for: selectedEmoji.id)), radius: 15)
                    } else {
                        Text("Select an Emoji")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)
                    }
                    // Search Bar
                    TextField("Search emojis...", text: $searchText)
                        .padding()
                        .frame(height: 40)
                        .background(Color.secondary.opacity(0.4))
                        .cornerRadius(10)
                    
                    ForEach(groupedEmojis.keys.sorted(), id: \.self) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group) // Display the group name
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            //   .padding(.leading)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                                ForEach(groupedEmojis[group]!) { emoji in
                                    ZStack {
                                        if selectedEmoji?.id == emoji.id {
                                            Circle()
                                                .stroke(Color.black, lineWidth: 3)
                                                .frame(width: 55, height: 55)
                                        }
                                        Text(emoji.id)
                                            .font(.largeTitle)
                                            .onTapGesture {
                                                withAnimation {
                                                    selectedEmoji = emoji
                                                }
                                            }
                                    }
                                    .frame(width: 55, height: 55)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                }
                
                
                VStack {
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .padding()
                            .frame(height: 55)
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .background(colorScheme == .dark ? .white : .black)
                            .cornerRadius(22)
                            .shadow(radius: 7)
                        
                            
                    }
                    .padding()
                }
                
            }
        }
        .padding()
        .onAppear {
                    groupedEmojisCache = Dictionary(grouping: emojis, by: { $0.group })
                }
    }
}

//
//#Preview {
//    EmojiPickerView(selectedEmoji: .con)
//}
