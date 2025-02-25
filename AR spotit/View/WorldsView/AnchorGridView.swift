//
//  AnchorGridView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//

import SwiftUI
// MARK: - AnchorGridView Subview
struct AnchorGridView: View {
    let filteredAnchors: [String]
    let colorScheme: ColorScheme
    let onAnchorTap: (String) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
            if char.isEmoji { return String(char) }
        }
        return nil
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 10) {
                if !filteredAnchors.isEmpty {
                    let anchors = filteredAnchors.filter { $0 != "guide" }
                    ForEach(Array(anchors.enumerated()), id: \.offset) { _, anchorName in
                        VStack {
                            let emoji = extractEmoji(from: anchorName) ?? "📍"
                            HStack {
                                Text(emoji)
                                    .font(.system(size: 50))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            let cleanAnchorName = anchorName.filter { !$0.isEmoji }
                            Text(cleanAnchorName)
                                .font(.system(.headline, design: .rounded))
                                .multilineTextAlignment(.center)
                                .bold()
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .padding()
                        .background(
                            VStack {
                                Spacer().frame(height: 55)
                                Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍"))
                                    .opacity(0.9)
                                    .frame(height: 55)
                                    .cornerRadius(22)
                            }
                        )
                        .cornerRadius(22)
                        .shadow(color: Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍")).opacity(0.7), radius: 7)
                        .onTapGesture { onAnchorTap(anchorName) }
                    }
                } else {
                    Text("No anchors found.")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}
