import SwiftUI

struct DownloadRow: View {
    @ObservedObject var task: DownloadTask
    @State private var pulse = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                // Video thumbnail
                if let thumbPath = task.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 45)
                        .cornerRadius(6)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 80, height: 45)
                        .overlay(
                            Image(systemName: "video")
                                .foregroundColor(.secondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    Text(task.statusDescription)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(task.format)
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.18))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                        
                        Text(task.quality)
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                        
                        statusPill(task.status)
                            .opacity(task.status == "Downloading" || task.status == "Converting" ? (pulse ? 0.6 : 1.0) : 1.0)
                        
                        if !task.fileSizeString.isEmpty {
                            Text(task.fileSizeString)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        DownloadManager.shared.cancelTask(id: task.id)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.8))
                        .imageScale(.large)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Cancel Download")
            }
            
            if task.status == "Downloading" || task.status == "Converting" {
                VStack(spacing: 6) {
                    // Custom Glowing Multi-Colored Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.18))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(
                                    colors: [Color.cyan, Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * CGFloat(task.progress))
                                .shadow(color: Color.cyan.opacity(0.4), radius: 3, x: 0, y: 0)
                        }
                    }
                    .frame(height: 6)
                    .padding(.vertical, 2)
                    
                    HStack {
                        if task.status == "Downloading" {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                Text(task.speed)
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(task.progress * 100))%")
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "hourglass")
                                Text("ETA: \(task.eta)")
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform.and.mic")
                                    .foregroundColor(.purple)
                                Text(task.statusDescription)
                                    .font(.system(.caption2, design: .rounded))
                                    .italic()
                            }
                            .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            } else if task.status == "Failed", let errMsg = task.errorMessage {
                Text("Error pipeline failed: \(errMsg)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
    
    private func statusPill(_ status: String) -> some View {
        let color: Color
        switch status {
        case "Queued":
            color = .orange
        case "Downloading":
            color = .blue
        case "Converting":
            color = .purple
        case "Completed":
            color = .green
        case "Failed":
            color = .red
        default:
            color = .secondary
        }
        
        return Text(status)
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
