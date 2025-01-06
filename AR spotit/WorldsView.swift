import SwiftUI

struct WorldsView: View {
    @ObservedObject var worldManager = WorldManager()
    @State private var selectedWorld: WorldModel? // Track which world is selected for adding anchors
    @State private var anchors: [String] = []
    @State private var anchorsByWorld: [String: [String]] = [:] // Track anchors for each world
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(worldManager.savedWorlds) { world in
                        VStack(alignment: .leading, spacing: 10) {
                            // Room Title
                            HStack {
                                Text(world.name)
                                    .font(.title2)
                                    .bold()
                                Spacer()
                                Button(action: {
                                    selectedWorld = world // Set the selected world
                                }) {
                                    Image(systemName: "plus.circle")
                                        .font(.title)
                                }
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    if let anchors = anchorsByWorld[world.name], !anchors.isEmpty {
                                        ForEach(anchors, id: \.self) { anchorName in
                                            Text(anchorName)
                                                .font(.caption)
                                                .padding()
                                                .frame(width: 100, height: 50)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    } else {
                                        Text("No anchors found.")
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .onAppear {
                                // Fetch anchors for this specific world
                                worldManager.getAnchorNames(for: world.name) { fetchedAnchors in
                                    anchorsByWorld[world.name] = fetchedAnchors // Store anchors by world name
                                }
                            }
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Saved Worlds")
            .toolbar {
                Button("Add World") {
                    selectedWorld = WorldModel(name: "")
                }
            }
            .sheet(item: $selectedWorld) { world in
                ContentView(currentRoomName: world.name)
            }
        }
    }
}
