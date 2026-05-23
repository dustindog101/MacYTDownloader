import SwiftUI

struct HistoryRow: View {
    let item: DownloadHistoryItem
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Video cached thumbnail
            if let thumbPath = item.thumbnailPath,
               let image = NSImage(contentsOfFile: thumbPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 50)
                    .cornerRadius(8)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 90, height: 50)
                    .overlay(
                        Image(systemName: "video.slash")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(item.format)
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.status == "completed" ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                        .foregroundColor(item.status == "completed" ? .green : .red)
                        .cornerRadius(4)
                    
                    Text(formatDuration(item.duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    if item.fileSize > 0 {
                        Text(formatFileSize(item.fileSize))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(item.downloadDate))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                if item.status == "completed" {
                    Button(action: {
                        let url = URL(fileURLWithPath: item.filePath)
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                    }) {
                        Image(systemName: "folder.fill")
                            .imageScale(.medium)
                            .foregroundColor(.accentColor)
                            .scaleEffect(isHovered ? 1.1 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Reveal in Finder")
                }
                
                Button(action: {
                    if let url = URL(string: item.url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "safari.fill")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open Original URL")
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .imageScale(.medium)
                        .foregroundColor(.red.opacity(0.8))
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete from History")
            }
            .padding(.trailing, 8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(isHovered ? Color.accentColor.opacity(0.04) : Color.clear)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1.2)
        )
        .shadow(color: isHovered ? Color.accentColor.opacity(0.08) : Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
        .onHover { hover in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                isHovered = hover
            }
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let secs = Int(duration)
        if secs <= 0 { return "0:00" }
        let hours = secs / 3600
        let mins = (secs % 3600) / 60
        let seconds = secs % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        } else {
            return String(format: "%d:%02d", mins, seconds)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
