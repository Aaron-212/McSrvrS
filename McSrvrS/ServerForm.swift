import SwiftData
import SwiftUI

struct ServerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: UInt16? = 25565
    
    // Optional server for editing
    let serverToEdit: Server?
    
    // Computed property to determine if we're editing
    private var isEditing: Bool {
        serverToEdit != nil
    }
    
    init(serverToEdit: Server? = nil) {
        self.serverToEdit = serverToEdit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Server Details"),
                    footer: Text("Default port for Minecraft servers is 25565")
                ) {
                    TextField("Server Name", text: $name)

                    TextField("Domain/IP Address", text: $host)
                    #if os(iOS)
                        .textInputAutocapitalization(.none)
                    #endif

                    TextField("Port", value: $port, formatter: NumberFormatter())
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                }
            }
            .navigationTitle(isEditing ? "Edit Server" : "Add Server")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #elseif os(macOS)
                .padding(32)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveServer()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if let serverToEdit = serverToEdit {
                    name = serverToEdit.name
                    host = serverToEdit.host
                    port = serverToEdit.port
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveServer() {
        let portNumber = port ?? 25565
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        var serverToUpdate: Server
        
        if let existingServer = serverToEdit {
            // Update existing server
            existingServer.name = trimmedName
            existingServer.host = trimmedHost
            existingServer.port = portNumber
            
            // Reset server state since host/port might have changed
            existingServer.serverState = .loading
            existingServer.lastUpdatedDate = Date()
            serverToUpdate = existingServer
        } else {
            // Create new server
            let newServer = Server(
                name: trimmedName,
                host: trimmedHost,
                port: portNumber
            )
            modelContext.insert(newServer)
            serverToUpdate = newServer
        }

        do {
            try modelContext.save()
            
            // Ping the server immediately after saving
            Task {
                await serverToUpdate.updateStatus()
            }
            
            dismiss()
        } catch {
            // Handle error - you might want to show an alert here
            print("Failed to save server: \(error)")
        }
    }
}

#Preview {
    ServerForm()
}
