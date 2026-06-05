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

                    LabeledContent("Host") {
                        TextField(text: $draft.host, prompt: Text(verbatim: "example.net")) {
                            EmptyView()
                        }
                            .autocorrectionDisabled()
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                            #endif
                    }

                    LabeledContent("Port") {
                        TextField(value: $draft.port, format: .number) {
                            EmptyView()
                        }
                            #if os(iOS)
                                .keyboardType(.numberPad)
                            #endif
                    }
                } header: {
                    Text("Server Details")
                } footer: {
                    Text("Default port for Minecraft servers is 25565")
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
                await ServerRefreshService.refresh(savedServer)
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
