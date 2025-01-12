import SwiftUI

struct RoomScanGuideView: View {
    

    
    @State private var currentTip = 1
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    init() {
            var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle) /// the default large title font
            titleFont = UIFont(
                descriptor:
                    titleFont.fontDescriptor
                    .withDesign(.rounded)? /// make rounded
                    .withSymbolicTraits(.traitBold) /// make bold
                    ??
                    titleFont.fontDescriptor, /// return the normal title if customization failed
                size: titleFont.pointSize
            )
            
            /// set the rounded font
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
        }
    var body: some View {
        NavigationStack {
            VStack {
                
                
                // Dynamic SF Symbol and guide text based on the current tip
                VStack {
                    guideSymbol(for: currentTip)
                        .font(.system(size: 200, design: .rounded))
                        .foregroundColor(guideColor(for: currentTip))
                        .frame(height: 300)
                        .padding()
                    
                    
                    Text(guideText(for: currentTip))
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding()
                    
                }
                .frame(height: 550)
                
                
                // Next button
                Button(action: {
                    if currentTip < 7 {
                        withAnimation {
                            currentTip += 1
                        }
                    } else {
                        
                        dismiss()
                    }
                }) {
                    Text(currentTip < 7 ? "Next" : "Start Scanning")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? .white : .black)
                        .cornerRadius(10)
                        .padding(.horizontal, 30)
                }
            }
          
            .padding()
            .navigationTitle("Tips")
        }
        

    }
    
    // Function to return the appropriate SF Symbol for each tip
    private func guideSymbol(for tip: Int) -> Image {
        switch tip {
        case 1: return Image(systemName: "door.right.hand.open")
        case 2: return Image(systemName: "lightbulb.max.fill")
        case 3: return Image(systemName: "tortoise.fill")
        case 4: return Image(systemName: "rectangle.3.offgrid.fill")
        case 5: return Image(systemName: "point.3.filled.connected.trianglepath.dotted")
        case 6: return Image(systemName: "text.bubble.fill")
        case 7: return Image(systemName: "hourglass")
        default: return Image(systemName: "questionmark")
        }
    }
    
    // Function to return the guide text for each tip
    private func guideText(for tip: Int) -> String {
        switch tip {
        case 1: return "Begin scanning from the entrance of the area for better room mapping and future findings."
        case 2: return "Ensure the room is well-lit for accurate scanning. Avoid shadows or overly bright spots."
        case 3: return "Move your device slowly and steadily to avoid incomplete scans."
        case 4: return "Scan walls, corners, and the floor. Aim to cover 60-70% of the area with the white mesh."
        case 5: return "Scan surfaces from different angles to capture every detail."
        case 6: return "Follow the on-screen scanning guide for optimal results."
        case 7: return "Take your time. A thorough scan ensures smooth and accurate AR interactions."
        default: return "You're ready to start scanning!"
        }
    }
    
    private func guideColor(for tip: Int) -> Color {
            switch tip {
            case 1: return .orange // Door
            case 2: return .yellow // Lightbulb
            case 3: return .green  // Tortoise
            case 4: return .purple // Mesh
            case 5: return .blue   // Arrows
            case 6: return .pink   // Hand tap
            case 7: return colorScheme == .dark ? .white : .black   // Hourglass
            default: return .black
            }
        }
}

#Preview {
    RoomScanGuideView()
}
