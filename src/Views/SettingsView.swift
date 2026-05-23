import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var updateManager = UpdateManager.shared
    @State private var isUpdating = false
    @State private var updateStatus = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    // Section 1: Output Folder Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Download Destination Folder")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 10) {
                            Text(settingsManager.outputDirectory.path)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                                .lineLimit(1)
                                .help(settingsManager.outputDirectory.path)
                            
                            Button(action: selectFolder) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Choose...")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Divider()
                    
                    // Section 2: UI Appearance Mode Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Application Theme Style")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Picker("Theme Options", selection: $settingsManager.appearanceMode) {
                            Text("System Synchronization").tag("system")
                            Text("Light Theme Mode").tag("light")
                            Text("Dark Theme Mode").tag("dark")
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                        .horizontalRadioGroupLayout()
                    }
                    
                    Divider()
                    
                    // Section 3: Application Software Updates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MacYT Downloader Software Updates")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                updateManager.checkForUpdates(manual: true)
                            }) {
                                HStack {
                                    if updateManager.isChecking {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "arrow.clockwise.circle")
                                    }
                                    
                                    if updateManager.isChecking {
                                        Text("Checking...")
                                    } else if updateManager.hasChecked && !updateManager.updateAvailable && updateManager.updateError == nil {
                                        Text("Up to Date")
                                    } else {
                                        Text("Check for Updates")
                                    }
                                }
                            }
                            .disabled(updateManager.isChecking || updateManager.isDownloading)
                            .buttonStyle(.borderedProminent)
                            
                            if updateManager.isChecking {
                                Text("Checking for new releases...")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else if let err = updateManager.updateError {
                                Text("Check failed: \(err)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.red)
                            } else if updateManager.hasChecked {
                                if updateManager.updateAvailable {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.right.circle.fill")
                                            .foregroundColor(.green)
                                        Text("v\(updateManager.latestRelease?.tagName.replacingOccurrences(of: "v", with: "") ?? "") is available!")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.green)
                                            .fontWeight(.bold)
                                        
                                        Button("View Update Details") {
                                            updateManager.showUpdateSheet = true
                                        }
                                        .buttonStyle(.link)
                                        .font(.system(.subheadline, design: .rounded))
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.accentColor)
                                        Text("You are on the latest version! (v\(updateManager.currentVersion))")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                        
                                        if updateManager.latestRelease != nil {
                                            Button("View Release Notes") {
                                                updateManager.showReleaseNotesSheet = true
                                            }
                                            .buttonStyle(.link)
                                            .font(.system(.subheadline, design: .rounded))
                                        }
                                    }
                                }
                            } else {
                                Text("Current Version: v\(updateManager.currentVersion)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section 4: Package Updates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("yt-dlp Downloader Updater")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            Button(action: updateYtDlp) {
                                HStack {
                                    if isUpdating {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    Text(isUpdating ? "Checking for Updates..." : "Check for Updates")
                                }
                            }
                            .disabled(isUpdating)
                            
                            if !updateStatus.isEmpty {
                                Text(updateStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose Download Folder Destination"
        panel.message = "All videos and audios will download into this directory."
        
        if panel.runModal() == .OK, let url = panel.url {
            settingsManager.outputDirectory = url
        }
    }
    
    private func updateYtDlp() {
        isUpdating = true
        updateStatus = "Connecting to updates server..."
        
        let path = YouTubeMetadataProvider.getExecutablePath(name: "yt-dlp")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-U"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            DispatchQueue.main.async {
                isUpdating = false
                if proc.terminationStatus == 0 {
                    if output.contains("up to date") || output.contains("Latest version") {
                        updateStatus = "yt-dlp is already up to date!"
                    } else {
                        updateStatus = "Successfully updated yt-dlp binary."
                    }
                } else {
                    updateStatus = "Update unavailable or failed."
                }
            }
        }
        
        do {
            try process.run()
        } catch {
            isUpdating = false
            updateStatus = "Execution error: \(error.localizedDescription)"
        }
    }
}
