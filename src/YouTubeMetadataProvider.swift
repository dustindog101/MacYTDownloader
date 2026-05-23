import Foundation

public struct YouTubeVideoInfo: Identifiable, Codable {
    public let id: String
    public let title: String
    public let thumbnail: String
    public let duration: Double
    public let uploader: String?
    public let description: String?
}

public class YouTubeMetadataProvider {
    public static func getExecutablePath(name: String) -> String {
        // 1. Check Bundle resources first
        if let bundlePath = Bundle.main.path(forResource: name, ofType: nil) {
            if FileManager.default.isExecutableFile(atPath: bundlePath) {
                return bundlePath
            }
        }
        // 2. Check standard Homebrew location (for arm64 Apple Silicon)
        let homebrewPath = "/opt/homebrew/bin/\(name)"
        if FileManager.default.fileExists(atPath: homebrewPath) {
            return homebrewPath
        }
        // 3. Check /usr/local/bin (for Intel/x86_64 or fallback installations)
        let localPath = "/usr/local/bin/\(name)"
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }
        // 4. Default back to env PATH resolution
        return name
    }
    
    public static func fetchMetadata(url: String, completion: @escaping (Result<YouTubeVideoInfo, Error>) -> Void) {
        let ytDlpPath = getExecutablePath(name: "yt-dlp")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = ["-j", "--no-playlist", url]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Inject /opt/homebrew/bin and /usr/local/bin so yt-dlp can locate 'deno'
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
        process.environment = env
        
        // Execute on a background thread immediately to prevent blocking standard pipe buffers
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                
                // Read concurrently to drain stdout and stderr blocks, avoiding 64KB OS deadlocks
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        let id = json["id"] as? String ?? UUID().uuidString
                        let title = json["title"] as? String ?? "Unknown Title"
                        
                        var thumbnailUrl = ""
                        if let thumbnail = json["thumbnail"] as? String {
                            thumbnailUrl = thumbnail
                        } else if let thumbnails = json["thumbnails"] as? [[String: Any]], !thumbnails.isEmpty {
                            thumbnailUrl = thumbnails.last?["url"] as? String ?? ""
                        }
                        
                        let duration = json["duration"] as? Double ?? 0.0
                        let uploader = json["uploader"] as? String
                        let description = json["description"] as? String
                        
                        let info = YouTubeVideoInfo(
                            id: id,
                            title: title,
                            thumbnail: thumbnailUrl,
                            duration: duration,
                            uploader: uploader,
                            description: description
                        )
                        completion(.success(info))
                    } else {
                        completion(.failure(NSError(domain: "MacYTDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse video info JSON metadata."])))
                    }
                } else {
                    let errMsg = String(data: errData, encoding: .utf8) ?? "yt-dlp encountered an error fetching metadata."
                    completion(.failure(NSError(domain: "MacYTDownloader", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg.trimmingCharacters(in: .whitespacesAndNewlines)])))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public static func downloadThumbnail(url: String, videoId: String, completion: @escaping (String?) -> Void) {
        guard let nsUrl = URL(string: url) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: nsUrl) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("MacYTDownloader/thumbnails", isDirectory: true)
            
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
            
            let localPath = appDir.appendingPathComponent("\(videoId).jpg")
            
            do {
                try data.write(to: localPath)
                completion(localPath.path)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}
