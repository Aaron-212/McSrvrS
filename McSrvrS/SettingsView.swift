import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("foregroundRefreshInterval") private var refreshInterval: Double = 300  // Default: 5 minutes (300 seconds)

    // Predefined refresh interval options
    private let refreshIntervalOptions: [Double] = [
        30,
        60,
        120,
        300,
        600,
        900,
        1800,
        3600,
        0,
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Foreground Auto Refresh", selection: $refreshInterval) {
                        ForEach(refreshIntervalOptions, id: \.self) { option in
                            if option == 0 {
                                Text("Never")
                                    .tag(option)
                            } else {
                                Text(
                                    Duration.seconds(option).formatted(
                                        .units(
                                            allowed: [.hours, .minutes, .seconds],
                                            width: .wide
                                        )
                                    )
                                )
                                .tag(option)
                            }
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
                    Text("Adjust how often the app updates the servers' information.")
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
                .navigationBarTitleDisplayMode(.inline)
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
