import SQLite3
import Foundation

public struct DownloadHistoryItem: Identifiable, Codable {
    public let id: String
    public let videoId: String
    public let title: String
    public let url: String
    public let format: String
    public let filePath: String
    public let thumbnailPath: String?
    public let duration: Double
    public let fileSize: Int64
    public let downloadDate: Date
    public let status: String // "completed", "failed"
}

public class HistoryDatabase {
    private var db: OpaquePointer?
    private let dbPath: String

    public init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MacYTDownloader", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        self.dbPath = appDir.appendingPathComponent("history.sqlite").path
        
        if sqlite3_open(self.dbPath, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        createTable()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS downloads (
            id TEXT PRIMARY KEY,
            video_id TEXT,
            title TEXT,
            url TEXT,
            format TEXT,
            file_path TEXT,
            thumbnail_path TEXT,
            duration REAL,
            file_size INTEGER,
            download_date REAL,
            status TEXT
        );
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error creating database table")
            }
        } else {
            print("Error preparing create database statement")
        }
        sqlite3_finalize(statement)
    }
    
    public func insert(item: DownloadHistoryItem) {
        let sql = "INSERT OR REPLACE INTO downloads (id, video_id, title, url, format, file_path, thumbnail_path, duration, file_size, download_date, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (item.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (item.videoId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (item.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (item.url as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 5, (item.format as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 6, (item.filePath as NSString).utf8String, -1, nil)
            if let thumb = item.thumbnailPath {
                sqlite3_bind_text(statement, 7, (thumb as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            sqlite3_bind_double(statement, 8, item.duration)
            sqlite3_bind_int64(statement, 9, item.fileSize)
            sqlite3_bind_double(statement, 10, item.downloadDate.timeIntervalSince1970)
            sqlite3_bind_text(statement, 11, (item.status as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                print("Error inserting download item: \(errmsg)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    public func fetchAll() -> [DownloadHistoryItem] {
        let sql = "SELECT id, video_id, title, url, format, file_path, thumbnail_path, duration, file_size, download_date, status FROM downloads ORDER BY download_date DESC;"
        var statement: OpaquePointer?
        var items: [DownloadHistoryItem] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let videoId = String(cString: sqlite3_column_text(statement, 1))
                let title = String(cString: sqlite3_column_text(statement, 2))
                let url = String(cString: sqlite3_column_text(statement, 3))
                let format = String(cString: sqlite3_column_text(statement, 4))
                let filePath = String(cString: sqlite3_column_text(statement, 5))
                
                var thumbnailPath: String? = nil
                if let thumbCol = sqlite3_column_text(statement, 6) {
                    thumbnailPath = String(cString: thumbCol)
                }
                
                let duration = sqlite3_column_double(statement, 7)
                let fileSize = sqlite3_column_int64(statement, 8)
                let downloadDateVal = sqlite3_column_double(statement, 9)
                let status = String(cString: sqlite3_column_text(statement, 10))
                
                let item = DownloadHistoryItem(
                    id: id,
                    videoId: videoId,
                    title: title,
                    url: url,
                    format: format,
                    filePath: filePath,
                    thumbnailPath: thumbnailPath,
                    duration: duration,
                    fileSize: fileSize,
                    downloadDate: Date(timeIntervalSince1970: downloadDateVal),
                    status: status
                )
                items.append(item)
            }
        }
        sqlite3_finalize(statement)
        return items
    }
    
    public func delete(id: String) {
        let sql = "DELETE FROM downloads WHERE id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error deleting download history item")
            }
        }
        sqlite3_finalize(statement)
    }
    
    public func clearAll() {
        let sql = "DELETE FROM downloads;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}
