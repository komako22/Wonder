import AppKit
import SwiftUI

@MainActor
final class WindowCoordinator {
    private let settings: SettingsStore
    private let client = TranslationClient()
    private let translationModel = TranslationViewModel()
    private let quickTranslationModel = QuickTranslationViewModel()

    private var bubblePanel: NSPanel?
    private var resultPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var quickTranslationWindow: NSWindow?
    private var currentSelection: SelectionSnapshot?
    private var translationTask: Task<Void, Never>?
    private var quickTranslationTask: Task<Void, Never>?
    private var quickDebounceTask: Task<Void, Never>?
    private var globalResultClickMonitor: Any?
    private var localResultClickMonitor: Any?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func showBubble(for selection: SelectionSnapshot) {
        currentSelection = selection
        let view = BubbleView(scale: settings.bubbleScale, theme: settings.glassTheme) { [weak self] in
            self?.translateCurrentSelection()
        }
        let panel = bubblePanel ?? makeBubblePanel()
        panel.contentView = NSHostingView(rootView: view)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        let size = NSSize(width: 60 * settings.bubbleScale, height: 48 * settings.bubbleScale)
        let pointer = NSEvent.mouseLocation
        let desired: NSPoint
        switch settings.bubblePosition {
        case .below:
            desired = NSPoint(x: selection.screenRect.midX - size.width / 2, y: selection.screenRect.minY - size.height - 6)
        case .above:
            desired = NSPoint(x: selection.screenRect.midX - size.width / 2, y: selection.screenRect.maxY + 6)
        case .pointer:
            desired = NSPoint(x: pointer.x + 8, y: pointer.y - size.height - 8)
        }
        panel.setContentSize(size)
        panel.setFrameOrigin(constrainedOrigin(desired, size: size, near: selection.screenRect))
        panel.orderFrontRegardless()
        bubblePanel = panel
    }

    func hideBubble() {
        bubblePanel?.orderOut(nil)
    }

    func hideResult() {
        translationTask?.cancel()
        resultPanel?.orderOut(nil)
        stopOutsideClickMonitoring()
    }

    func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                onSave: { _ in },
                openAccessibility: { [weak self] in self?.openAccessibilitySettings() }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Wonder 设置"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showQuickTranslator() {
        if quickTranslationWindow == nil {
            let view = QuickTranslationView(
                model: quickTranslationModel,
                scheduleTranslation: { [weak self] in self?.scheduleQuickTranslation() },
                close: { [weak self] in self?.quickTranslationWindow?.orderOut(nil) }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 430),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Wonder 翻译"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            quickTranslationWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        quickTranslationWindow?.makeKeyAndOrderFront(nil)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func translateCurrentSelection() {
        guard let selection = currentSelection else { return }
        hideBubble()
        translationTask?.cancel()
        translationModel.source = selection.text
        translationModel.state = .loading
        showResultPanel(near: selection.screenRect)

        let configuration = TranslationClient.Configuration(
            sourceLanguage: .automatic,
            targetLanguage: settings.targetLanguage,
            freeServiceEmail: settings.freeServiceEmail
        )
        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await client.translate(selection.text, configuration: configuration)
                guard !Task.isCancelled else { return }
                translationModel.state = .result(result)
                resizeResultPanel(source: selection.text, translation: result, near: selection.screenRect)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                translationModel.state = .failure(error.localizedDescription)
            }
        }
    }

    private func scheduleQuickTranslation() {
        quickDebounceTask?.cancel()
        quickTranslationTask?.cancel()
        let source = quickTranslationModel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            quickTranslationModel.output = ""
            quickTranslationModel.errorMessage = ""
            quickTranslationModel.isTranslating = false
            return
        }

        quickTranslationModel.output = ""
        quickTranslationModel.errorMessage = ""
        quickTranslationModel.isTranslating = true
        quickDebounceTask = Task { [weak self] in
            try? await Task<Never, Never>.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.translateQuickInput()
        }
    }

    private func translateQuickInput() {
        let source = quickTranslationModel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        quickTranslationTask?.cancel()
        let configuration = TranslationClient.Configuration(
            sourceLanguage: quickTranslationModel.sourceLanguage,
            targetLanguage: quickTranslationModel.targetLanguage,
            freeServiceEmail: settings.freeServiceEmail
        )
        quickTranslationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await client.translate(source, configuration: configuration)
                guard !Task.isCancelled else { return }
                quickTranslationModel.output = result
                quickTranslationModel.isTranslating = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                quickTranslationModel.errorMessage = error.localizedDescription
                quickTranslationModel.isTranslating = false
            }
        }
    }

    private func retryTranslation() {
        translateCurrentSelection()
    }

    private func showResultPanel(near rect: CGRect) {
        let content = TranslationCardView(
            model: translationModel,
            settings: settings,
            retry: { [weak self] in self?.retryTranslation() },
            close: { [weak self] in self?.hideResult() }
        )
        let panel = resultPanel ?? makeResultPanel()
        panel.contentView = NSHostingView(rootView: content)
        let size = NSSize(
            width: 390,
            height: preferredResultHeight(source: translationModel.source, translation: nil, near: rect)
        )
        let preferred = NSPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 12)
        panel.setContentSize(size)
        panel.setFrameOrigin(constrainedOrigin(preferred, size: size, near: rect))
        panel.makeKeyAndOrderFront(nil)
        resultPanel = panel
        startOutsideClickMonitoring()
    }

    private func resizeResultPanel(source: String, translation: String, near rect: CGRect) {
        guard let panel = resultPanel, panel.isVisible else { return }
        let size = NSSize(
            width: 390,
            height: preferredResultHeight(source: source, translation: translation, near: rect)
        )
        let preferred = NSPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 12)
        panel.setContentSize(size)
        panel.setFrameOrigin(constrainedOrigin(preferred, size: size, near: rect))
    }

    private func preferredResultHeight(source: String, translation: String?, near rect: CGRect) -> CGFloat {
        let textWidth: CGFloat = 334
        let sourceHeight: CGFloat
        if settings.showSourceText {
            sourceHeight = min(52, measuredTextHeight(source, font: .systemFont(ofSize: 13), width: textWidth))
        } else {
            sourceHeight = 0
        }

        let translationHeight: CGFloat
        if let translation {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = -2
            translationHeight = measuredTextHeight(
                translation,
                font: .systemFont(ofSize: settings.translationFontSize, weight: .medium),
                width: textWidth,
                paragraphStyle: paragraph
            )
        } else {
            translationHeight = 28
        }

        let fixedHeight: CGFloat = settings.showSourceText ? 130 : 90
        let desired = fixedHeight + sourceHeight + translationHeight
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) ?? NSScreen.main
        let maximum = min(520, max(260, (screen?.visibleFrame.height ?? 600) - 40))
        return min(max(desired, settings.showSourceText ? 220 : 180), maximum)
    }

    private func measuredTextHeight(
        _ text: String,
        font: NSFont,
        width: CGFloat,
        paragraphStyle: NSParagraphStyle? = nil
    ) -> CGFloat {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let paragraphStyle { attributes[.paragraphStyle] = paragraphStyle }
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return ceil(bounds.height)
    }

    private func makeBubblePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        return panel
    }

    private func makeResultPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 250),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        return panel
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        globalResultClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismissResultIfClickIsOutside() }
        }
        localResultClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissResultIfClickIsOutside()
            return event
        }
    }

    private func stopOutsideClickMonitoring() {
        if let monitor = globalResultClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localResultClickMonitor { NSEvent.removeMonitor(monitor) }
        globalResultClickMonitor = nil
        localResultClickMonitor = nil
    }

    private func dismissResultIfClickIsOutside() {
        guard let panel = resultPanel, panel.isVisible else { return }
        if !panel.frame.contains(NSEvent.mouseLocation) {
            hideResult()
        }
    }

    private func constrainedOrigin(_ desired: NSPoint, size: NSSize, near rect: CGRect) -> NSPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return desired }
        var x = max(visible.minX + 8, min(desired.x, visible.maxX - size.width - 8))
        var y = desired.y
        if y < visible.minY + 8 {
            y = rect.maxY + 10
        }
        y = max(visible.minY + 8, min(y, visible.maxY - size.height - 8))
        if !x.isFinite { x = visible.midX - size.width / 2 }
        return NSPoint(x: x, y: y)
    }
}
