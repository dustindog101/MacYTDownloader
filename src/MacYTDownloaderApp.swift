import SwiftUI

@main
struct MacYTDownloaderApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .navigationTitle("MacYT Downloader")
        }
        .windowStyle(TitleBarWindowStyle())
    }
}
