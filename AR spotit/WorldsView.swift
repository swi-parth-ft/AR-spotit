import SwiftUI

struct WorldsView: View {
    @ObservedObject var worldManager = WorldManager()
    @State private var selectedWorld: WorldModel? // Track which world is selected for adding anchors

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

                            // Anchors
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    let anchors = worldManager.getAnchorNames(for: world.name)

                                    if anchors.isEmpty {
                                        Text("No anchors found.")
                                            .foregroundColor(.secondary)
                                            .padding()
                                    } else {
                                        ForEach(anchors, id: \.self) { anchorName in
                                            Text(anchorName)
                                                .font(.caption)
                                                .padding()
                                                .frame(width: 100, height: 50)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Saved Worlds")
            .sheet(item: $selectedWorld) { world in
                ContentView(currentRoomName: world.name)
            }
        }
    }
}
