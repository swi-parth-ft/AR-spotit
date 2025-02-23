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
                Spacer()
                if AppState.shared.isViewOnly {
                    Text("Would you like to open now and start exploring or save copy locally?")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal)
                } else {
                    Text("Would you like to open now and start editing or save copy locally?")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal)
                }
               
              
                
                Button {
                    onOpen()
                } label: {
                    Text(AppState.shared.isViewOnly ? "Start Exploring" : "Open Now and Collaborate")
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
                    Text("Save Copy Locally")
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
