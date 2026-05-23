import SwiftUI
import UniformTypeIdentifiers

enum NavigationTab: String, CaseIterable, Identifiable {
    case downloader = "Downloader"
    case history = "History"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .downloader: return "arrow.down.circle"
        case .history: return "clock"
        case .settings: return "gear"
        }
    }
}

struct MovingBlobsView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.14), Color.blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: animate ? 320 : 220, height: animate ? 320 : 220)
                .blur(radius: 65)
                .offset(x: animate ? -60 : 70, y: animate ? -80 : 60)
            
            Circle()
                .fill(LinearGradient(colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: animate ? 260 : 380, height: animate ? 260 : 380)
                .blur(radius: 75)
                .offset(x: animate ? 120 : -40, y: animate ? 90 : -30)
            
            Circle()
                .fill(LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: animate ? 340 : 240, height: animate ? 340 : 240)
                .blur(radius: 80)
                .offset(x: animate ? -30 : -80, y: animate ? 130 : 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct MainView: View {
    @State private var selectedTab: NavigationTab = .downloader
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var updateManager = UpdateManager.shared
    
    @State private var historyItems: [DownloadHistoryItem] = []
    
    @State private var urlInput = ""
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var parsedVideoInfo: YouTubeVideoInfo?
    
    @State private var selectedFormat = "MP4"
    @State private var selectedQuality = "Balanced"
    @State private var isSearchFocused = false
    @State private var showUpdateSheet = false
    
    let formats = ["MP4", "MP4 (No Audio)", "MP3", "FLAC", "WAV", "Opus", "M4A"]
    let db = HistoryDatabase()
    
    private var qualityOptions: [String] {
        if selectedFormat.contains("MP4") {
            return ["Best (4K/1080p)", "Balanced (720p)", "Storage Saver (480p)"]
        } else if ["FLAC", "WAV"].contains(selectedFormat) {
            return ["Lossless (Highest)"]
        } else {
            return ["Best (320 kbps)", "Balanced (192 kbps)", "Storage Saver (96 kbps)"]
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(NavigationTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.iconName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .listStyle(SidebarListStyle())
        } detail: {
            ZStack {
                Color(NSColor.underPageBackgroundColor)
                    .ignoresSafeArea()
                
                MovingBlobsView()
                    .ignoresSafeArea()
                
                switch selectedTab {
                case .downloader:
                    downloaderPanel
                case .history:
                    historyPanel
                case .settings:
                    SettingsView(settingsManager: settingsManager)
                }
            }
        }
        .onAppear {
            settingsManager.applyAppearance()
            loadHistory()
            // Auto check for updates on launch quietly (Great UX)
            updateManager.checkForUpdates()
        }
        .frame(minWidth: 800, minHeight: 540)
        .sheet(isPresented: $showUpdateSheet) {
            updateModalSheet
        }
        .onChange(of: updateManager.updateAvailable) { newValue in
            if newValue {
                showUpdateSheet = true
            }
        }
    }
    
    private var downloaderPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("MacYT Downloader")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundColor(isSearchFocused ? .accentColor : .secondary)
                            .font(.headline)
                        
                        TextField("Paste YouTube video link here to analyze...", text: $urlInput, onCommit: analyzeUrl)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(.body, design: .rounded))
                            .disabled(isAnalyzing)
                            .onHover { inside in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isSearchFocused = inside
                                }
                            }
                        
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 22, height: 22)
                        } else if !urlInput.isEmpty {
                            Button(action: {
                                urlInput = ""
                                parsedVideoInfo = nil
                                analysisError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSearchFocused ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.18), lineWidth: 1.2)
                    )
                    .shadow(color: isSearchFocused ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    
                    Button(action: analyzeUrl) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Analyze")
                        }
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(urlInput.isEmpty || isAnalyzing)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 20)
            
            VStack {
                if let video = parsedVideoInfo {
                    videoPreviewCard(video)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else if let err = analysisError {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        Text(err)
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.red)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
                } else {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.25), Color.blue.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Drag & Drop YouTube Link Here")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                            
                            Text("Supports standard watch URLs, YouTube shorts, and live streams.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                    .onDrop(of: [.url, .text], isTargeted: nil) { providers in
                        handleDragDrop(providers)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 24)
            
            Divider()
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Active Queue Pipeline")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    if !downloadManager.tasks.isEmpty {
                        Button(action: {
                            withAnimation {
                                downloadManager.clearCompleted()
                                loadHistory()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.circle")
                                Text("Clear Finished")
                            }
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                if downloadManager.tasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Pipeline idle. Add downloads to start processing.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 24)
                } else {
                    List(downloadManager.tasks) { task in
                        DownloadRow(task: task)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "folder.circle.fill")
                        .foregroundColor(.purple)
                        .font(.largeTitle)
                    
                    Text("Download Archives")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.black)
                }
                
                Spacer()
                
                if !historyItems.isEmpty {
                    Button(action: {
                        let alert = NSAlert()
                        alert.messageText = "Flush Archives Log?"
                        alert.informativeText = "This completely cleans the SQLite history catalog. Completed downloads are NOT deleted from your folder."
                        alert.addButton(withTitle: "Flush Logs")
                        alert.addButton(withTitle: "Cancel")
                        if alert.runModal() == .alertFirstButtonReturn {
                            db.clearAll()
                            loadHistory()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clear History Log")
                        }
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 18)
            
            Divider()
                .padding(.horizontal, 24)
            
            if historyItems.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No records stored in local SQLite database.")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(historyItems) { item in
                        HistoryRow(item: item, onDelete: {
                            db.delete(id: item.id)
                            loadHistory()
                        })
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadHistory()
        }
    }
    
    @ViewBuilder
    private func videoPreviewCard(_ video: YouTubeVideoInfo) -> some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.thumbnail)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 170, height: 100)
                            .cornerRadius(10)
                            .clipped()
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 170, height: 100)
                            .overlay(
                                Image(systemName: "video.fill")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                Text(formatDuration(video.duration))
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(4)
                    .padding(6)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if let uploader = video.uploader {
                        Text(uploader)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }
                
                HStack(spacing: 16) {
                    Picker("Format", selection: $selectedFormat.onChange(formatChanged)) {
                        ForEach(formats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .frame(width: 150)
                    
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(qualityOptions, id: \.self) { quality in
                            Text(quality).tag(getInternalQualityValue(from: quality))
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .frame(width: 200)
                    .disabled(qualityOptions.count <= 1)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            let internalQuality = getInternalQualityValue(from: selectedQuality)
                            downloadManager.addTask(info: video, format: selectedFormat, quality: internalQuality, immediate: false, outputDir: settingsManager.outputDirectory)
                            parsedVideoInfo = nil
                            urlInput = ""
                        }
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.indent")
                            Text("Queue Download")
                        }
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        withAnimation {
                            let internalQuality = getInternalQualityValue(from: selectedQuality)
                            downloadManager.addTask(info: video, format: selectedFormat, quality: internalQuality, immediate: true, outputDir: settingsManager.outputDirectory)
                            parsedVideoInfo = nil
                            urlInput = ""
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Download Immediately")
                        }
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 6, x: 0, y: 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.25), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    // Glowing Liquid Glass Update sheet (Premium macOS 26 UX)
    private var updateModalSheet: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Software Update Available")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.black)
                    
                    if let release = updateManager.latestRelease {
                        Text("Version \(release.tagName) is ready for download.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.top, 8)
            
            Divider()
            
            if let release = updateManager.latestRelease {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Changelog / Release Notes:")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                        
                        Text(release.body)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: 140)
                .padding(12)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            Spacer()
            
            if updateManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: updateManager.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .accentColor(.accentColor)
                    
                    Text(updateManager.downloadStatus)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Button("Cancel Download") {
                        updateManager.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 14) {
                    Spacer()
                    
                    Button("Skip Version") {
                        showUpdateSheet = false
                        updateManager.updateAvailable = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        updateManager.startUpdateDownload()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Download & Install")
                        }
                        .fontWeight(.bold)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 460, height: 320)
        .background(.ultraThinMaterial)
    }
    
    private func loadHistory() {
        historyItems = db.fetchAll()
    }
    
    private func formatChanged(to newFormat: String) {
        if ["FLAC", "WAV"].contains(newFormat) {
            selectedQuality = "Best"
        } else {
            selectedQuality = "Balanced"
        }
    }
    
    private func getInternalQualityValue(from displayString: String) -> String {
        if displayString.contains("Best") {
            return "Best"
        } else if displayString.contains("Balanced") {
            return "Balanced"
        } else if displayString.contains("Storage Saver") {
            return "Storage Saver"
        } else if displayString.contains("Lossless") {
            return "Best"
        } else {
            return displayString
        }
    }
    
    private func analyzeUrl() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isAnalyzing = true
        analysisError = nil
        parsedVideoInfo = nil
        
        YouTubeMetadataProvider.fetchMetadata(url: trimmed) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                switch result {
                case .success(let info):
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        self.parsedVideoInfo = info
                        self.selectedFormat = "MP4" // Reset selection back to default on new query
                        self.selectedQuality = "Balanced"
                    }
                case .failure(let error):
                    withAnimation {
                        self.analysisError = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func handleDragDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        self.urlInput = url.absoluteString
                        self.analyzeUrl()
                    }
                }
            }
            return true
        } else if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { string, error in
                if let string = string {
                    DispatchQueue.main.async {
                        self.urlInput = string
                        self.analyzeUrl()
                    }
                }
            }
            return true
        }
        return false
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
}

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}
