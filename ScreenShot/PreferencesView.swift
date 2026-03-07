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

                Section("GIF Recording Shortcut") {
                    Toggle("Enable", isOn: $settings.enableGIFShortcut)

                    if settings.enableGIFShortcut {
                        HStack {
                            Text("Shortcut:")
                            Spacer()
                            KeyComboView(key: $settings.gifShortcutKey, modifiers: $settings.gifShortcutModifiers)
                        }
                    }
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
    @Binding var modifiers: NSEvent.ModifierFlags

    var modifiersText: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        return parts.joined(separator: "")
    }

    var body: some View {
        VStack {
            HStack(spacing: 4) {
                Toggle("⌘", isOn: Binding(
                    get: { modifiers.contains(.command) },
                    set: { if $0 { modifiers.insert(.command) } else { modifiers.remove(.command) } }
                ))
                .frame(width: 30)

                Toggle("⇧", isOn: Binding(
                    get: { modifiers.contains(.shift) },
                    set: { if $0 { modifiers.insert(.shift) } else { modifiers.remove(.shift) } }
                ))
                .frame(width: 30)

                Toggle("⌃", isOn: Binding(
                    get: { modifiers.contains(.control) },
                    set: { if $0 { modifiers.insert(.control) } else { modifiers.remove(.control) } }
                ))
                .frame(width: 30)

                Toggle("⌥", isOn: Binding(
                    get: { modifiers.contains(.option) },
                    set: { if $0 { modifiers.insert(.option) } else { modifiers.remove(.option) } }
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
