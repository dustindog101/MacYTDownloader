import Foundation
import Combine

public class DownloadTask: ObservableObject, Identifiable {
    public let id: String
    public let videoId: String
    public let title: String
    public let url: String
    public let format: String
    public let quality: String
    public let thumbnailPath: String?
    public let duration: Double
    
    @Published public var progress: Double = 0.0 // 0.0 to 1.0
    @Published public var speed: String = ""
    @Published public var eta: String = ""
    @Published public var status: String = "Queued" // "Queued", "Downloading", "Converting", "Completed", "Failed"
    @Published public var statusDescription: String = "Queued in pipeline" // Premium UX description
    @Published public var errorMessage: String?
    @Published public var fileSizeString: String = ""
    
    public var process: Process?
    public var startDate: Date?
    
    public init(videoId: String, title: String, url: String, format: String, quality: String, thumbnailPath: String?, duration: Double) {
        self.id = UUID().uuidString
        self.videoId = videoId
        self.title = title
        self.url = url
        self.format = format
        self.quality = quality
        self.thumbnailPath = thumbnailPath
        self.duration = duration
    }
}

public class DownloadManager: ObservableObject {
    @Published public var tasks: [DownloadTask] = []
    
    private let db = HistoryDatabase()
    private let maxConcurrentDownloads = 2
    private let queueQueue = DispatchQueue(label: "tech.cybershare.downloadqueue")
    
    public static let shared = DownloadManager()
    
    private init() {}
    
    public func addTask(info: YouTubeVideoInfo, format: String, quality: String, immediate: Bool, outputDir: URL) {
        // Download thumbnail first for offline visual history representation
        YouTubeMetadataProvider.downloadThumbnail(url: info.thumbnail, videoId: info.id) { localThumb in
            DispatchQueue.main.async {
                let task = DownloadTask(
                    videoId: info.id,
                    title: info.title,
                    url: "https://www.youtube.com/watch?v=\(info.id)",
                    format: format,
                    quality: quality,
                    thumbnailPath: localThumb,
                    duration: info.duration
                )
                self.tasks.append(task)
                
                if immediate {
                    self.startDownload(task: task, outputDir: outputDir)
                } else {
                    self.processQueue(outputDir: outputDir)
                }
            }
        }
    }
    
    public func processQueue(outputDir: URL) {
        queueQueue.async {
            let downloadingCount = self.tasks.filter { $0.status == "Downloading" || $0.status == "Converting" }.count
            
            if downloadingCount < self.maxConcurrentDownloads {
                if let nextTask = self.tasks.first(where: { $0.status == "Queued" }) {
                    self.startDownload(task: nextTask, outputDir: outputDir)
                }
            }
        }
    }
    
    private func startDownload(task: DownloadTask, outputDir: URL) {
        DispatchQueue.main.async {
            task.status = "Downloading"
            task.statusDescription = "Initializing pipeline..."
            task.startDate = Date()
        }
        
        let ytDlpPath = YouTubeMetadataProvider.getExecutablePath(name: "yt-dlp")
        let ffmpegPath = YouTubeMetadataProvider.getExecutablePath(name: "ffmpeg")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        // Inject /opt/homebrew/bin and /usr/local/bin so yt-dlp can locate dependencies
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
        process.environment = env
        
        let outputTemplate = outputDir.appendingPathComponent("%(title)s.%(ext)s").path
        
        var arguments = [
            "--no-playlist",
            "--newline",
            "--progress",
            "--concurrent-fragments", "5",
            "--ffmpeg-location", ffmpegPath,
            "-o", outputTemplate
        ]
        
        if task.format == "MP4" {
            var videoFilter = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
            
            if task.quality == "Balanced" {
                videoFilter = "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best[height<=1080]/best"
            } else if task.quality == "Storage Saver" {
                videoFilter = "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best[height<=480]/best"
            }
            
            arguments.append(contentsOf: [
                "-f", videoFilter,
                "--merge-output-format", "mp4"
            ])
        } else if task.format == "MP4 (No Audio)" {
            // Download Video Only stream (No Audio track to conserve disk space)
            var videoFilter = "bestvideo[ext=mp4]/bestvideo"
            
            if task.quality == "Balanced" {
                videoFilter = "bestvideo[height<=1080][ext=mp4]/bestvideo[height<=1080]"
            } else if task.quality == "Storage Saver" {
                videoFilter = "bestvideo[height<=480][ext=mp4]/bestvideo[height<=480]"
            }
            
            arguments.append(contentsOf: [
                "-f", videoFilter
            ])
        } else {
            var audioQualityArg = "0"
            
            if task.quality == "Balanced" {
                audioQualityArg = "5"
            } else if task.quality == "Storage Saver" {
                audioQualityArg = "9"
            }
            
            arguments.append(contentsOf: [
                "-x",
                "--audio-format", task.format.lowercased(),
                "--audio-quality", audioQualityArg
            ])
        }
        
        arguments.append(task.url)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        task.process = process
        
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.waitForDataInBackgroundAndNotify()
        
        class ObserverBox {
            var observer: NSObjectProtocol?
        }
        let box = ObserverBox()
        
        box.observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSFileHandleDataAvailable,
            object: outputHandle,
            queue: nil
        ) { [weak self, weak task] notification in
            guard let self = self, let task = task else { return }
            let data = outputHandle.availableData
            if data.isEmpty {
                if let obs = box.observer {
                    NotificationCenter.default.removeObserver(obs)
                }
                return
            }
            
            if let outputLine = String(data: data, encoding: .utf8) {
                self.parseOutputLine(outputLine, task: task)
            }
            
            outputHandle.waitForDataInBackgroundAndNotify()
        }
        
        process.terminationHandler = { [weak self, weak task] proc in
            guard let self = self, let task = task else { return }
            
            let status = proc.terminationStatus
            
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                if status == 0 {
                    task.status = "Completed"
                    task.statusDescription = "Completed successfully"
                    task.progress = 1.0
                    task.speed = ""
                    task.eta = ""
                    
                    let actualFilePath = self.findDownloadedFile(title: task.title, format: task.format, outputDir: outputDir)
                    
                    var fileSize: Int64 = 0
                    if let filePath = actualFilePath,
                       let attr = try? FileManager.default.attributesOfItem(atPath: filePath) {
                        fileSize = attr[.size] as? Int64 ?? 0
                    }
                    
                    let combinedFormat = "\(task.format) (\(task.quality))"
                    
                    let historyItem = DownloadHistoryItem(
                        id: task.id,
                        videoId: task.videoId,
                        title: task.title,
                        url: task.url,
                        format: combinedFormat,
                        filePath: actualFilePath ?? outputDir.appendingPathComponent(task.title).path,
                        thumbnailPath: task.thumbnailPath,
                        duration: task.duration,
                        fileSize: fileSize,
                        downloadDate: Date(),
                        status: "completed"
                    )
                    self.db.insert(item: historyItem)
                    
                } else {
                    task.status = "Failed"
                    task.statusDescription = "Process failed"
                    task.errorMessage = (errStr == nil || errStr!.isEmpty) ? "Error code \(status)" : errStr
                    
                    let combinedFormat = "\(task.format) (\(task.quality))"
                    
                    let historyItem = DownloadHistoryItem(
                        id: task.id,
                        videoId: task.videoId,
                        title: task.title,
                        url: task.url,
                        format: combinedFormat,
                        filePath: "",
                        thumbnailPath: task.thumbnailPath,
                        duration: task.duration,
                        fileSize: 0,
                        downloadDate: Date(),
                        status: "failed"
                    )
                    self.db.insert(item: historyItem)
                }
                
                self.processQueue(outputDir: outputDir)
            }
        }
        
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                task.status = "Failed"
                task.statusDescription = "Spawning failed"
                task.errorMessage = error.localizedDescription
                self.processQueue(outputDir: outputDir)
            }
        }
    }
    
    private func parseOutputLine(_ line: String, task: DownloadTask) {
        let cleanLines = line.components(separatedBy: .newlines)
        for cleanLine in cleanLines {
            let trimmed = cleanLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.contains("[download] Destination:") {
                let lower = trimmed.lowercased()
                if lower.contains(".mp4") && lower.contains(".f") {
                    DispatchQueue.main.async { task.statusDescription = "Downloading video stream..." }
                } else if lower.contains(".m4a") && lower.contains(".f") {
                    DispatchQueue.main.async { task.statusDescription = "Downloading audio stream..." }
                } else {
                    DispatchQueue.main.async { task.statusDescription = "Downloading media file..." }
                }
            } else if trimmed.contains("[Merger]") || trimmed.contains("Merging formats") {
                DispatchQueue.main.async {
                    task.status = "Converting"
                    task.statusDescription = "Merging video & audio tracks..."
                }
            } else if trimmed.contains("[ExtractAudio]") {
                DispatchQueue.main.async {
                    task.status = "Converting"
                    task.statusDescription = "Extracting audio track..."
                }
            } else if trimmed.contains("[ffmpeg]") {
                DispatchQueue.main.async {
                    task.status = "Converting"
                    task.statusDescription = "Converting audio codecs via ffmpeg..."
                }
            }
            
            if trimmed.contains("[download]") && trimmed.contains("%") {
                if let pctRange = trimmed.range(of: "\\d+(\\.\\d+)?%", options: .regularExpression) {
                    let pctStr = String(trimmed[pctRange]).replacingOccurrences(of: "%", with: "")
                    if let pct = Double(pctStr) {
                        DispatchQueue.main.async {
                            task.progress = pct / 100.0
                            if task.status != "Downloading" {
                                task.status = "Downloading"
                            }
                        }
                    }
                }
                
                if let speedRange = trimmed.range(of: "at\\s+\\d+(\\.\\d+)?[KM]iB/s", options: .regularExpression) {
                    let speedStr = String(trimmed[speedRange]).replacingOccurrences(of: "at ", with: "")
                    DispatchQueue.main.async {
                        task.speed = speedStr
                    }
                }
                
                if let sizeRange = trimmed.range(of: "of\\s+~?\\d+(\\.\\d+)?[KM]iB", options: .regularExpression) {
                    let sizeStr = String(trimmed[sizeRange]).replacingOccurrences(of: "of ", with: "")
                    DispatchQueue.main.async {
                        task.fileSizeString = sizeStr
                    }
                }
                
                if let startDate = task.startDate {
                    let elapsed = Date().timeIntervalSince(startDate)
                    if task.progress > 0.01 {
                        let totalTime = elapsed / task.progress
                        let remaining = max(0, totalTime - elapsed)
                        
                        let secs = Int(remaining)
                        let mins = secs / 60
                        let seconds = secs % 60
                        let etaString = String(format: "%02d:%02d", mins, seconds)
                        
                        DispatchQueue.main.async {
                            task.eta = etaString
                        }
                    }
                }
            }
        }
    }
    
    private func findDownloadedFile(title: String, format: String, outputDir: URL) -> String? {
        let fileManager = FileManager.default
        let extensionLower = format.contains("MP4") ? "mp4" : format.lowercased()
        
        let expectedFile = outputDir.appendingPathComponent("\(title).\(extensionLower)")
        if fileManager.fileExists(atPath: expectedFile.path) {
            return expectedFile.path
        }
        
        if let files = try? fileManager.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil) {
            let cleanTitle = title.replacingOccurrences(of: "/", with: "_")
                                  .replacingOccurrences(of: ":", with: "_")
                                  .replacingOccurrences(of: "\"", with: "_")
                                  .replacingOccurrences(of: "?", with: "_")
            for file in files {
                if file.pathExtension.lowercased() == extensionLower {
                    let fileName = file.deletingPathExtension().lastPathComponent
                    if fileName.contains(cleanTitle) || cleanTitle.contains(fileName) {
                        return file.path
                    }
                }
            }
        }
        return nil
    }
    
    public func cancelTask(id: String) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let task = tasks[index]
            task.process?.terminate()
            tasks.remove(at: index)
        }
    }
    
    public func clearCompleted() {
        tasks.removeAll { $0.status == "Completed" || $0.status == "Failed" }
    }
}
