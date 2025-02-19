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

struct OpenOrSaveSheet: View {
    var roomName: String
    var assetFileURL: URL
    var sharedRecord: CKRecord
    var onOpen: () -> Void
    var onSave: () -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        
        
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Would you like to open now or save copy locally?")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
               
               
              
                
                Button {
                    onOpen()
                } label: {
                    Text("Open Now")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button {
                    onSave()
                } label: {
                    Text("Save Locally")
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

            .navigationTitle("Choose Action")
     
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
