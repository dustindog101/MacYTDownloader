import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
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
                    
                    // Section 3: Package Updates
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
