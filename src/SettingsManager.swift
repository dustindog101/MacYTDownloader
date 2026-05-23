import Foundation
import AppKit
import SwiftUI

public class SettingsManager: ObservableObject {
    @Published public var outputDirectory: URL {
        didSet {
            UserDefaults.standard.set(outputDirectory.path, forKey: "outputDirectory")
        }
    }
    
    @Published public var appearanceMode: String {
        didSet {
            UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
            applyAppearance()
        }
    }
    
    public init() {
        let defaultPath: String
        if let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            defaultPath = downloadsDir.path
        } else {
            defaultPath = NSHomeDirectory() + "/Downloads"
        }
        
        let path = UserDefaults.standard.string(forKey: "outputDirectory") ?? defaultPath
        self.outputDirectory = URL(fileURLWithPath: path)
        
        self.appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
    }
    
    public func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case "light":
                NSApp.appearance = NSAppearance(named: .aqua)
            case "dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                NSApp.appearance = nil // Follow OS setting
            }
        }
    }
}
