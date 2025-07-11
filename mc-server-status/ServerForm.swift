import SwiftData
import SwiftUI

struct ServerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: UInt16? = 25565
    
    // Add ServerPinger instance
    private let serverPinger = ServerPinger()

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
            .navigationTitle("Add Server")
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
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveServer() {
        let portNumber = port ?? 25565

        let newServer = Server(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: portNumber
        )

        modelContext.insert(newServer)

        do {
            try modelContext.save()
            
            // Ping the server immediately after saving
            Task {
                await newServer.updateStatus(using: serverPinger)
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
