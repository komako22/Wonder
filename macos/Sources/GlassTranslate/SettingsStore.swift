import Foundation
import ApplicationServices
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var targetLanguage: TargetLanguage
    @Published var freeServiceEmail: String
    @Published var launchAtLogin: Bool
    @Published var isPaused: Bool
    @Published var selectionMethod: SelectionMethod
    @Published var selectionDelay: Double
    @Published var bubbleScale: Double
    @Published var bubblePosition: BubblePosition
    @Published var glassTheme: GlassTheme
    @Published var translationFontSize: Double
    @Published var showSourceText: Bool
    @Published var accessibilityGranted: Bool

    private let defaults = UserDefaults.standard
    private init() {
        targetLanguage = TargetLanguage(rawValue: defaults.string(forKey: "targetLanguage") ?? "") ?? .automatic
        freeServiceEmail = defaults.string(forKey: "freeServiceEmail") ?? ""
        isPaused = defaults.bool(forKey: "isPaused")
        selectionMethod = SelectionMethod(rawValue: defaults.string(forKey: "selectionMethod") ?? "") ?? .automatic
        selectionDelay = defaults.object(forKey: "selectionDelay") as? Double ?? 0.18
        bubbleScale = defaults.object(forKey: "bubbleScale") as? Double ?? 1.0
        bubblePosition = BubblePosition(rawValue: defaults.string(forKey: "bubblePosition") ?? "") ?? .below
        glassTheme = GlassTheme(rawValue: defaults.string(forKey: "glassTheme") ?? "") ?? .aurora
        translationFontSize = defaults.object(forKey: "translationFontSize") as? Double ?? 16
        showSourceText = defaults.object(forKey: "showSourceText") as? Bool ?? true
        accessibilityGranted = AXIsProcessTrusted()
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = false
        }
    }

    func refreshAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func save() throws {
        defaults.set(targetLanguage.rawValue, forKey: "targetLanguage")
        defaults.set(freeServiceEmail.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "freeServiceEmail")
        defaults.set(isPaused, forKey: "isPaused")
        defaults.set(selectionMethod.rawValue, forKey: "selectionMethod")
        defaults.set(selectionDelay, forKey: "selectionDelay")
        defaults.set(bubbleScale, forKey: "bubbleScale")
        defaults.set(bubblePosition.rawValue, forKey: "bubblePosition")
        defaults.set(glassTheme.rawValue, forKey: "glassTheme")
        defaults.set(translationFontSize, forKey: "translationFontSize")
        defaults.set(showSourceText, forKey: "showSourceText")
        try updateLaunchAtLogin()
    }

    private func updateLaunchAtLogin() throws {
        if #available(macOS 13.0, *) {
            if launchAtLogin, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            } else if !launchAtLogin, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
