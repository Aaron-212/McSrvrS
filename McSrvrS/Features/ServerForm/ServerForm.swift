import SwiftData
import SwiftUI
import os

struct ServerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ServerFormDraft

    let editingServer: Server?

    private var isEditing: Bool {
        editingServer != nil
    }

    init(editingServer: Server? = nil) {
        self.editingServer = editingServer
        draft = ServerFormDraft(server: editingServer)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Server Name") {
                        TextField(text: $draft.name, prompt: Text("Example Server")) {
                            EmptyView()
                        }
                    }
                        .textFieldStyle(.automatic)

                    LabeledContent("Address") {
                        TextField(text: $draft.address, prompt: Text(verbatim: "example.net or example.net:25565")) {
                            EmptyView()
                        }
                            .autocorrectionDisabled()
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                            #endif
                    }
                } header: {
                    Text("Server Details")
                } footer: {
                    Text("Port is optional. Add one only when the server requires an explicit port.")
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
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    private func saveServer() {
        let savedServer: Server

        if let existingServer = editingServer {
            draft.apply(to: existingServer)
            savedServer = existingServer
        } else {
            let descriptor = FetchDescriptor<Server>()
            let serverCount = (try? modelContext.fetchCount(descriptor)) ?? 0

            let newServer = draft.makeServer(orderIndex: serverCount)
            modelContext.insert(newServer)
            savedServer = newServer
        }

        do {
            try modelContext.save()

            Task {
                await ServerRefreshService.refresh(
                    savedServer.id,
                    modelContainer: modelContext.container
                )
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
