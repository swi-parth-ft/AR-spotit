//
//  SwiftUIView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-27.
//

import SwiftUI
import ARKit

struct ExploreSharedView: View {
    var arWorldMap: ARWorldMap?
    @State private var anchorNames: [String] = []
    @State var findAnchor: String = ""
    var onTap: (String) -> Void = { _ in }
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    @State private var searchText: String = ""
    @Environment(\.colorScheme) var colorScheme
    
    var filteredAnchors: [String] {
    
        return anchorNames.filter { anchor in
             guard anchor != "guide" else { return false }
             // Remove any emojis from the anchor name before searching.
             let cleanAnchor = anchor.filter { !$0.isEmoji }
             return searchText.isEmpty || cleanAnchor.localizedCaseInsensitiveContains(searchText)
         }
     }
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
            
            ZStack {
                (colorScheme == .dark ? Color.black : Color.white)
                       .ignoresSafeArea()
                VStack {
                    
                    
                    
                    if let image = AppState.shared.sharedWorldImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 400)
                            .clipped()
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(LinearGradient(colors: [.black.opacity(1.0), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))
                                
                            )
                            .conditionalModifier(colorScheme != .dark) { view in
                                view.colorInvert()
                            }
                            .frame(width: UIScreen.main.bounds.width, height: 400)
                            
                        
                        
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading) {
                    
                    Text("Tap on items you want to find or browse entire \(WorldManager.shared.sharedWorldName ?? "")")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    ScrollView {
                        
                       

                        
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            
                            if anchorNames != [] {
                                //
                                ForEach(Array(filteredAnchors.enumerated()), id: \.0) { index, anchorName in
                                    VStack {
                                        // Extract and display the emoji if present
                                        let emoji = extractEmoji(from: anchorName)
                                        HStack {
                                            Text(emoji ?? "📍")
                                                .font(.system(size: 50))
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        // Display the anchor name without the emoji
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
                                            
                                            Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍")).opacity(0.9).frame(height: 55) // Use extracted color
                                                .cornerRadius(22)
                                            
                                        }
                                    )
                                    .cornerRadius(22)
                                    .shadow(color: Color(getDominantColor(for: extractEmoji(from: anchorName) ?? "📍")).opacity(0.7), radius: 7)
                                    .onTapGesture {
                                        
                                        onTap(anchorName)
                                        
                                        
                                        
                                    }
                                }
                            }
                            
                        }
                        .padding()
                        .searchable(text: $searchText,
                                    placement: .navigationBarDrawer(displayMode: .automatic),
                                    prompt: "Search Items")
                        
                    }
                    Spacer()
                    Button {
                        onTap("")
                    } label: {
                        HStack {
                            Text("Browse in AR")
                            
                            
                            Image(systemName: "arkit")
                            
                        }
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary.opacity(1))
                        .cornerRadius(10)
                    }
                    .padding()
                    
                }
                .onAppear {
                    if let arWorldMap = arWorldMap {
                        arWorldMap.anchors.forEach { anchor in
                            if anchor.name != nil && anchor.name != "guide" {
                                anchorNames.append(anchor.name ?? "")
                                
                            }
                        }
                    }
                    UISearchBar.appearance().tintColor = colorScheme == .dark ? .white : .black
                    
                }
                .navigationTitle("Explore \(WorldManager.shared.sharedWorldName ?? "")")
            }
        }
    }
}

#Preview {
    ExploreSharedView()
}
