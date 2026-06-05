import SwiftData
import SwiftUI
import os

struct ServerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: UInt16? = 25565

    let editingServer: Server?

    private var isEditing: Bool {
        editingServer != nil
    }

    init(editingServer: Server? = nil) {
        self.editingServer = editingServer
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Server Details"),
                    footer: Text("Default port for Minecraft servers is 25565")
                ) {
                    LabeledContent("Server Name") {
                        TextField(text: $name, prompt: Text("Example Server")) {
                            EmptyView()
                        }
                    }
                        .textFieldStyle(.automatic)

                    LabeledContent("Host") {
                        TextField(text: $host, prompt: Text(verbatim: "example.net")) {
                            EmptyView()
                        }
                            .autocorrectionDisabled()
                            #if os(iOS)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                            #endif
                    }

                    LabeledContent("Port") {
                        TextField(value: $port, format: .number) {
                            EmptyView()
                        }
                            #if os(iOS)
                                .keyboardType(.numberPad)
                            #endif
                    }
                }
            }
            .formStyle(.grouped)
            .multilineTextAlignment(.trailing)
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
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if let editingServer {
                    name = editingServer.name
                    host = editingServer.host
                    port = editingServer.port
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

        let savedServer: Server

        if let existingServer = editingServer {
            existingServer.name = trimmedName
            existingServer.host = trimmedHost
            existingServer.port = portNumber
            existingServer.lastUpdatedDate = Date()

            savedServer = existingServer
        } else {
            let descriptor = FetchDescriptor<Server>()
            let serverCount = (try? modelContext.fetchCount(descriptor)) ?? 0

            let newServer = Server(
                name: trimmedName,
                host: trimmedHost,
                port: portNumber,
                orderIndex: serverCount
            )
            modelContext.insert(newServer)
            savedServer = newServer
        }

        do {
            try modelContext.save()

            Task {
                await savedServer.updateStatus()
            }

            dismiss()
        } catch {
            log.error("Failed to save server: \(error)")
        }
    }
}

#Preview {
    ServerForm()
}
