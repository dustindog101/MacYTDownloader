import Foundation
import AppKit
import Combine

public struct GitHubRelease: Codable {
    public let tagName: String
    public let name: String
    public let body: String
    public let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, assets
    }
}

public struct GitHubAsset: Codable {
    public let name: String
    public let size: Int64
    public let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name, size
        case browserDownloadUrl = "browser_download_url"
    }
}

public class UpdateManager: NSObject, ObservableObject {
    public static let shared = UpdateManager()
    
    @Published public var isChecking = false
    @Published public var isDownloading = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadStatus = ""
    @Published public var latestRelease: GitHubRelease?
    @Published public var updateAvailable = false
    
    // New states for premium UX update flow
    @Published public var hasChecked = false
    @Published public var updateError: String? = nil
    @Published public var showUpdateSheet = false
    @Published public var showReleaseNotesSheet = false
    
    public let currentVersion = "1.0.1"
    public let repoPath = "dustindog101/MacYTDownloader"
    
    private var downloadTask: URLSessionDownloadTask?
    
    private override init() {
        super.init()
    }
    
    public func checkForUpdates(manual: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard !isChecking && !isDownloading else { return }
        
        DispatchQueue.main.async {
            self.isChecking = true
            self.updateError = nil
        }
        
        let urlString = "https://api.github.com/repos/\(repoPath)/releases/latest"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isChecking = false
                self.updateError = "Invalid update server address."
            }
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("MacYTDownloader-Updater", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isChecking = false
                self.hasChecked = true
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.updateError = error.localizedDescription
                }
                completion?(false)
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.updateError = "No response from updates server."
                }
                completion?(false)
                return
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                
                let cleanLatest = release.tagName.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanCurrent = self.currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let isNewer = self.isVersion(cleanLatest, newerThan: cleanCurrent)
                
                DispatchQueue.main.async {
                    self.latestRelease = release
                    if isNewer {
                        self.updateAvailable = true
                        self.showUpdateSheet = true // Automatically pop up details and download dialog
                        completion?(true)
                    } else {
                        self.updateAvailable = false
                        completion?(false)
                    }
                }
            } catch {
                print("Error parsing release JSON: \(error)")
                DispatchQueue.main.async {
                    self.updateError = "Failed to parse release notes metadata."
                }
                completion?(false)
            }
        }.resume()
    }
    
    private func isVersion(_ version1: String, newerThan version2: String) -> Bool {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let val1 = i < v1Components.count ? v1Components[i] : 0
            let val2 = i < v2Components.count ? v2Components[i] : 0
            
            if val1 > val2 {
                return true
            } else if val1 < val2 {
                return false
            }
        }
        return false
    }
    
    public func startUpdateDownload() {
        guard let release = latestRelease,
              let dmgAsset = release.assets.first(where: { $0.name.lowercased().contains(".dmg") }),
              let url = URL(string: dmgAsset.browserDownloadUrl) else {
            return
        }
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.downloadStatus = "Downloading update installer..."
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        
        DispatchQueue.main.async {
            self.isDownloading = false
            self.downloadStatus = ""
            self.downloadProgress = 0.0
        }
    }
    
    private func installDMG(at localUrl: URL) {
        DispatchQueue.main.async {
            self.downloadStatus = "Mounting update..."
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", "-nobrowse", "-readonly", localUrl.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { [weak self] proc in
            guard let self = self else { return }
            
            guard proc.terminationStatus == 0 else {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadStatus = "Failed to mount update installer."
                }
                return
            }
            
            // Find the mounted volume path
            let mountPath = "/Volumes/MacYT Downloader"
            let sourceAppPath = "\(mountPath)/MacYTDownloader.app"
            let targetAppPath = Bundle.main.bundlePath
            let parentPid = ProcessInfo.processInfo.processIdentifier
            
            guard FileManager.default.fileExists(atPath: sourceAppPath) else {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadStatus = "Update files missing inside mounted image."
                }
                // Cleanup and force unmount
                let detachProc = Process()
                detachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProc.arguments = ["detach", mountPath, "-force"]
                try? detachProc.run()
                return
            }
            
            // Spawns a background script that waits for parent to exit, copies the new bundle, detaches image, and relaunch.
            let script = """
            (
                # Wait for parent app to fully terminate
                while kill -0 \(parentPid) 2>/dev/null; do
                    sleep 0.1
                done
                
                # Delete existing bundle and copy the new one
                rm -rf "\(targetAppPath)"
                cp -R "\(sourceAppPath)" "\(targetAppPath)"
                
                # Unmount and clean up mounted disk volume
                hdiutil detach "\(mountPath)" -force
                
                # Open the new updated application
                open "\(targetAppPath)"
            ) &
            """
            
            let updaterProcess = Process()
            updaterProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
            updaterProcess.arguments = ["-c", script]
            
            do {
                try updaterProcess.run()
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadStatus = ""
                    self.updateAvailable = false
                    
                    // Terminate parent app to let the background installer execute replacement and relaunch!
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadStatus = "Failed to run background update installer: \(error.localizedDescription)"
                }
            }
        }
        
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadStatus = "Execution error mounting update: \(error.localizedDescription)"
            }
        }
    }
}

extension UpdateManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let updateDir = appSupport.appendingPathComponent("MacYTDownloader/updates", isDirectory: true)
        
        try? fileManager.createDirectory(at: updateDir, withIntermediateDirectories: true, attributes: nil)
        
        let destinationUrl = updateDir.appendingPathComponent("MacYT_Downloader_Update.dmg")
        
        try? fileManager.removeItem(at: destinationUrl)
        
        do {
            try fileManager.moveItem(at: location, to: destinationUrl)
            self.installDMG(at: destinationUrl)
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadStatus = "Failed to copy installer: \(error.localizedDescription)"
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadProgress = progress
                let pct = Int(progress * 100)
                self.downloadStatus = "Downloading update installer: \(pct)%"
            }
        }
    }
}
