import SwiftUI

struct PreferencesView: View {
    @State var settings: AppSettings
    @State var config: AppConfig
    @State var testConnectionStatus = ""

    var body: some View {
        TabView {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $settings.serverURL)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Test Connection") {
                            testConnection()
                        }
                        Spacer()
                        if !testConnectionStatus.isEmpty {
                            Text(testConnectionStatus)
                                .font(.caption)
                                .foregroundColor(testConnectionStatus.contains("✓") ? .green : .red)
                        }
                    }
                }

                Section("Image Capture Shortcut") {
                    Toggle("Enable", isOn: $settings.enableImageShortcut)

                    if settings.enableImageShortcut {
                        HStack {
                            Text("Shortcut:")
                            Spacer()
                            KeyComboView(key: $settings.imageShortcutKey, modifiers: $settings.imageShortcutModifiers)
                        }
                    }
                }

                Section("GIF Recording (Coming Soon)") {
                    Text("GIF recording will be available in a future update")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tabItem {
                Image(systemName: "gear")
                Text("General")
            }

            Form {
                Section("Save Settings") {
                    Toggle("Save all captured images", isOn: $settings.saveAllImages)

                    if settings.saveAllImages {
                        HStack {
                            Text("Save to:")
                            Spacer()
                            Button(action: { selectSaveDirectory() }) {
                                Text(settings.saveDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .lineLimit(1)
                                Image(systemName: "folder")
                            }
                        }
                    }
                }

                Section("Notifications") {
                    Toggle("Play sound on completion", isOn: $settings.enableSound)
                }

                Section("GIF Recording") {
                    HStack {
                        Text("Frame rate:")
                        Spacer()
                        Stepper(value: $settings.gifFrameRate, in: 1...30) {
                            Text("\(settings.gifFrameRate) fps")
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: "slider.horizontal.3")
                Text("Capture")
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func testConnection() {
        guard !settings.serverURL.isEmpty else {
            testConnectionStatus = "❌ No server URL configured"
            return
        }

        Task {
            do {
                let url = URL(string: settings.serverURL)!
                var request = URLRequest(url: url)
                request.timeoutInterval = 5

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    testConnectionStatus = "✓ Connection successful"
                } else {
                    testConnectionStatus = "❌ Server unreachable"
                }
            } catch {
                testConnectionStatus = "❌ Connection failed"
            }
        }
    }

    private func selectSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: settings.saveDirectory)

        if panel.runModal() == .OK, let url = panel.url {
            settings.saveDirectory = url.path
        }
    }
}

struct KeyComboView: View {
    @Binding var key: String
    @Binding var modifiers: UInt

    var body: some View {
        let modifierFlags = NSEvent.ModifierFlags(rawValue: modifiers)

        return VStack {
            HStack(spacing: 4) {
                Toggle("⌘", isOn: Binding(
                    get: { modifierFlags.contains(.command) },
                    set: {
                        var flags = modifierFlags
                        if $0 { flags.insert(.command) } else { flags.remove(.command) }
                        modifiers = flags.rawValue
                    }
                ))
                .frame(width: 30)

                Toggle("⇧", isOn: Binding(
                    get: { modifierFlags.contains(.shift) },
                    set: {
                        var flags = modifierFlags
                        if $0 { flags.insert(.shift) } else { flags.remove(.shift) }
                        modifiers = flags.rawValue
                    }
                ))
                .frame(width: 30)

                Toggle("⌃", isOn: Binding(
                    get: { modifierFlags.contains(.control) },
                    set: {
                        var flags = modifierFlags
                        if $0 { flags.insert(.control) } else { flags.remove(.control) }
                        modifiers = flags.rawValue
                    }
                ))
                .frame(width: 30)

                Toggle("⌥", isOn: Binding(
                    get: { modifierFlags.contains(.option) },
                    set: {
                        var flags = modifierFlags
                        if $0 { flags.insert(.option) } else { flags.remove(.option) }
                        modifiers = flags.rawValue
                    }
                ))
                .frame(width: 30)

                TextField("Key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
            }
        }
    }
}

#Preview {
    PreferencesView(
        settings: AppSettings(),
        config: AppConfig()
    )
}
