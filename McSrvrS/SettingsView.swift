import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKey.foregroundRefreshInterval) private var foregroundRefreshInterval: Double = 300
    @AppStorage(AppStorageKey.backgroundRefreshInterval) private var backgroundRefreshInterval: Double = 900

    private let foregroundRefreshIntervalOptions: [Double] = [
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

    private let backgroundRefreshIntervalOptions: [Double] = [
        900,
        1800,
        3600,
        7200,
        10800,
        14400,
        0,
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Foreground Auto Refresh", selection: $foregroundRefreshInterval) {
                        ForEach(foregroundRefreshIntervalOptions, id: \.self) { option in
                            refreshIntervalLabel(for: option)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: foregroundRefreshInterval) { _, newValue in
                        NotificationCenter.default.post(
                            name: .refreshIntervalChanged,
                            object: nil,
                            userInfo: ["interval": newValue]
                        )
                    }
                } header: {
                    Text("Foreground Refresh")
                } footer: {
                    Text("Adjust how often the app updates server information while it is open.")
                }

                Section {
                    Picker("Background Auto Refresh", selection: $backgroundRefreshInterval) {
                        ForEach(backgroundRefreshIntervalOptions, id: \.self) { option in
                            refreshIntervalLabel(for: option)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Background Refresh")
                } footer: {
                    Text("Adjust the earliest interval for background refresh scheduling.")
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
            .frame(width: 500, height: 360)
        #endif
    }

    private func refreshIntervalLabel(for interval: Double) -> Text {
        if interval == 0 {
            Text("Never")
        } else {
            Text(
                Duration.seconds(interval).formatted(
                    .units(
                        allowed: [.hours, .minutes, .seconds],
                        width: .wide
                    )
                )
            )
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
