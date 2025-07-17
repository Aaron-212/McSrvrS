import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("foregroundRefreshInterval") private var refreshInterval: Double = 300  // Default: 5 minutes (300 seconds)

    // Predefined refresh interval options
    private let refreshIntervalOptions: [(String, TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("Never", 0),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Foreground Refresh", selection: $refreshInterval) {
                        ForEach(refreshIntervalOptions, id: \.1) { option in
                            Text(option.0)
                                .tag(option.1)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: refreshInterval) { _, newValue in
                        // Post notification to update the timer
                        NotificationCenter.default.post(
                            name: .refreshIntervalChanged,
                            object: nil,
                            userInfo: ["interval": newValue]
                        )
                    }
                } header: {
                    Text("Refresh Settings")
                } footer: {
                    Text("Adjust how often the app checks for server updates the servers' information.")
                }
            }
            .navigationTitle("Settings")
            .formStyle(.grouped)
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            #endif
        }
        #if os(macOS)
            .frame(width: 500, height: 300)
        #endif
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
