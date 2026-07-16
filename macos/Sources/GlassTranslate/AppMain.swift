import AppKit
import SwiftUI

@main
struct WonderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = SettingsStore.shared
    private lazy var windows = WindowCoordinator(settings: settings)
    private lazy var selectionMonitor = SelectionMonitor(settings: settings)
    private var statusItem: NSStatusItem?
    private var pauseItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var permissionTimer: Timer?
    private var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()

        selectionMonitor.onSelectionStarted = { [weak self] in
            self?.windows.hideBubble()
        }
        selectionMonitor.onSelection = { [weak self] snapshot in
            guard let self, !settings.isPaused else { return }
            windows.showBubble(for: snapshot)
        }
        selectionMonitor.start()
        refreshAccessibilityStatus()
        permissionTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshAccessibilityStatus),
            userInfo: nil,
            repeats: true
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        selectionMonitor.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let icon = NSApplication.shared.applicationIconImage.copy() as? NSImage
            icon?.size = NSSize(width: 18, height: 18)
            icon?.isTemplate = false
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Wonder"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Wonder", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let translateItem = NSMenuItem(title: "打开翻译", action: #selector(openQuickTranslator), keyEquivalent: "t")
        translateItem.target = self
        menu.addItem(translateItem)
        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: settings.isPaused ? "继续划词监听" : "暂停划词监听",
            action: #selector(togglePaused),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)
        pauseItem = pause

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionItem = NSMenuItem(title: accessibilityTitle(), action: #selector(openAccessibility), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)
        accessibilityItem = permissionItem
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 Wonder", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusMenu = menu
        statusItem = item
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp,
           let menu = statusMenu,
           let button = statusItem?.button {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else {
            windows.showQuickTranslator()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshAccessibilityStatus()
    }

    private func accessibilityTitle() -> String {
        settings.accessibilityGranted
            ? "辅助功能权限：已开启"
            : "辅助功能权限：未开启…"
    }

    @objc private func refreshAccessibilityStatus() {
        let wasGranted = settings.accessibilityGranted
        settings.refreshAccessibilityPermission()
        accessibilityItem?.title = accessibilityTitle()
        if !wasGranted, settings.accessibilityGranted {
            selectionMonitor.start()
        }
    }

    @objc private func togglePaused() {
        settings.isPaused.toggle()
        try? settings.save()
        pauseItem?.title = settings.isPaused ? "继续划词监听" : "暂停划词监听"
        if settings.isPaused {
            windows.hideBubble()
            windows.hideResult()
        }
    }

    @objc private func openSettings() {
        refreshAccessibilityStatus()
        windows.showSettings()
    }

    @objc private func openQuickTranslator() {
        windows.showQuickTranslator()
    }

    @objc private func openAccessibility() {
        windows.openAccessibilitySettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
