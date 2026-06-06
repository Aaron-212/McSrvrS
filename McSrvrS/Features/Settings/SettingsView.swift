import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKey.foregroundRefreshInterval) private var foregroundRefreshInterval: Double = 300
    @AppStorage(AppStorageKey.backgroundRefreshInterval) private var backgroundRefreshInterval: Double = 900

    #if os(macOS)
        @AppStorage(AppStorageKey.showsMenuBarExtra) private var showsMenuBarExtra = true
    #endif

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
                #if os(macOS)
                    Section {
                        Toggle("Show Menu Bar Item", isOn: $showsMenuBarExtra)
                    } header: {
                        Text("Menu Bar")
                    } footer: {
                        Text("Show McSrvrS in the menu bar for quick server status access.")
                    }
                #endif

                Section {
                    Picker("Foreground Auto Refresh", selection: $foregroundRefreshInterval) {
                        ForEach(foregroundRefreshIntervalOptions, id: \.self) { option in
                            durationLabel(for: option, zeroLabel: "Never")
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

                    Picker("Background Auto Refresh", selection: $backgroundRefreshInterval) {
                        ForEach(backgroundRefreshIntervalOptions, id: \.self) { option in
                            durationLabel(for: option, zeroLabel: "Never")
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                } header: {
                    Text("Refresh Interval")
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
            .frame(width: 500, height: 420)
        #endif
    }

    private func durationLabel(for duration: Double, zeroLabel: String? = nil) -> Text {
        if duration == 0, let zeroLabel {
            Text(zeroLabel)
        } else {
            Text(
                Duration.seconds(duration).formatted(
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
