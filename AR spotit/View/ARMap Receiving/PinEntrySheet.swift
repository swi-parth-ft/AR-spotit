import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight
import CloudKit

// MARK: - SwiftUI Sheets

struct PinEntrySheet: View {
    @State private var pin: String = ""
    var roomName: String
    var storedPinHash: String
    var onConfirm: (String) -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        
        NavigationStack {
            VStack(alignment: .leading) {
                Spacer()
                Text("Enter Key for \(roomName) collaboration")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
               
               
              
                    TextField("Key", text: $pin)
                        .focused($isTextFieldFocused)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .padding()
                        .frame(height: 55)
                        .background(Color.secondary.opacity(0.4))
                        .cornerRadius(10)
                        .tint(.primary)
                        .padding(.horizontal)
                        .onAppear {
                            
                                isTextFieldFocused = true
                            
                        }
                
                Button {
                    
                    onConfirm(pin)
                    pin = ""
                } label: {
                    Text("Next")
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
            .padding(.bottom)
            .navigationTitle("Key Required")
     
            .toolbar {
          
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                     

                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                
            }
           
        }

    }
}

