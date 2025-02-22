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

// Same loading function
func loadEmojis() -> [EmojiDetails] {
    guard let url = Bundle.main.url(forResource: "emojis", withExtension: "json") else {
        print("Failed to find emojis.json")
        return []
    }
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let rawEmojis = try decoder.decode([String: EmojiDetails].self, from: data)
        
        // Convert dict to array
        return rawEmojis.map { key, value in
            var details = value
            details.emoji = key
            return details
        }
    } catch {
        print("Failed to decode emojis.json: \(error)")
        return []
    }
}

struct EmojiPickerView: View {
    // Hard-coded group order
    let groupOrder = [
       
        "Animals & Nature",
        "Food & Drink",
        "Objects",
        "Travel & Places",
        "Smileys & Emotion",
        "Activities",
        "People & Body",
        "Symbols",
        "Flags"
    ]
    
    @State private var searchText: String = ""
    @Binding var selectedEmoji: EmojiDetails?
    let emojis: [EmojiDetails] = loadEmojis()
    @State private var groupedEmojisCache: [String: [EmojiDetails]] = [:]
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var filteredEmojis: [EmojiDetails] {
        if searchText.isEmpty {
            return emojis
        } else {
            return emojis.filter { e in
                e.name.lowercased().contains(searchText.lowercased()) ||
                e.group.lowercased().contains(searchText.lowercased()) ||
                e.slug.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    // Group by group name
    var groupedEmojis: [String: [EmojiDetails]] {
        if searchText.isEmpty {
            return groupedEmojisCache
        } else {
            return Dictionary(grouping: filteredEmojis, by: { $0.group })
        }
    }
    
    // Return groups in fixed order, each sorted by emoji
    var orderedGroups: [(groupName: String, emojis: [EmojiDetails])] {
        groupOrder.compactMap { groupName in
            guard let list = groupedEmojis[groupName] else { return nil }
            let sortedList = list.sorted { $0.emoji < $1.emoji }
            return (groupName, sortedList)
        }
    }
    
    var body: some View {
        ZStack {
            // 1) ScrollViewReader to jump around
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        if let sel = selectedEmoji {
                            Text(sel.emoji)
                                .font(.system(size: 100))
                                .padding()
                                .shadow(color: .gray, radius: 15)
                        } else {
                            Text("Select an Emoji")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.bottom, 10)
                        }
                        
                        TextField("Search emojis...", text: $searchText)
                            .padding()
                            .frame(height: 40)
                            .background(Color.secondary.opacity(0.4))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        // 2) ForEach each group, use .id(groupName)
                        ForEach(orderedGroups, id: \.groupName) { (groupName, emojiList) in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(groupName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 10) {
                                    ForEach(emojiList) { emoji in
                                        ZStack {
                                            if selectedEmoji?.id == emoji.id {
                                                Circle()
                                                    .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 3)
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
                            .id(groupName) // So we can scrollTo(groupName)
                        }
                        
                        Spacer().frame(height: 80) // leave room for the Done button
                    }
                }
                .onAppear {
                    groupedEmojisCache = Dictionary(grouping: emojis, by: { $0.group })
                }
                
                // 3) Right-side index: each group’s *first* emoji
                VStack {
                    Spacer()
                    // We’ll place it at the trailing edge
                }
                
                // Or an overlay alignment
                .overlay(
                    VStack(spacing: 6) {
                        ForEach(orderedGroups, id: \.groupName) { (groupName, emojiList) in
                            Button {
                                withAnimation {
                                    proxy.scrollTo(groupName, anchor: .top)
                                }
                            } label: {
                                // Show first emoji if available, else a placeholder
                                if let firstEmoji = emojiList.first?.emoji {
                                    Text(firstEmoji)
                                        .font(.title2)
                                } else {
                                    Text("?")
                                }
                            }
                        }
                    }
                    .padding(.trailing, 5)
                    .padding(.vertical, 20)
                    , alignment: .trailing
                )
            }
            
            // 4) “Done” button at bottom
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
}
