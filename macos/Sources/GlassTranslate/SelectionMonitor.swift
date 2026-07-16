import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class SelectionMonitor {
    var onSelection: ((SelectionSnapshot) -> Void)?
    var onSelectionStarted: (() -> Void)?

    private var monitors: [Any] = []
    private var pendingTask: Task<Void, Never>?
    private var lastSignature = ""
    private var mouseDownLocation: CGPoint?
    private let maximumCharacters = 8_000
    private let minimumDragDistance: CGFloat = 4
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        stop()
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: { [weak self] _ in
            Task { @MainActor in
                self?.mouseDownLocation = NSEvent.mouseLocation
                self?.pendingTask?.cancel()
                self?.lastSignature = ""
                self?.onSelectionStarted?()
            }
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp], handler: { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                let currentLocation = NSEvent.mouseLocation
                let distance = self.mouseDownLocation.map { hypot(currentLocation.x - $0.x, currentLocation.y - $0.y) } ?? 0
                let isDrag = distance >= self.minimumDragDistance
                let isDoubleClick = event.clickCount >= 2
                let isShiftSelection = event.modifierFlags.contains(.shift)
                self.mouseDownLocation = nil
                guard isDrag || isDoubleClick || isShiftSelection else { return }
                self.scheduleRead(allowClipboardFallback: isDrag || isShiftSelection)
            }
        }) {
            monitors.append(monitor)
        }
    }

    func stop() {
        pendingTask?.cancel()
        pendingTask = nil
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }

    private func scheduleRead(allowClipboardFallback: Bool) {
        pendingTask?.cancel()
        let nanoseconds = UInt64(max(0.05, settings.selectionDelay) * 1_000_000_000)
        pendingTask = Task { [weak self] in
            try? await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self?.readSelection(allowClipboardFallback: allowClipboardFallback)
        }
    }

    private func readSelection(allowClipboardFallback: Bool) async {
        var result: SelectionSnapshot?
        if hasAccessibilityPermission, settings.selectionMethod != .clipboardOnly {
            result = readAccessibilitySelection()
        }
        if result == nil, allowClipboardFallback, settings.selectionMethod != .accessibilityOnly {
            result = await readClipboardSelection()
        }
        guard let result, result.signature != lastSignature else { return }
        lastSignature = result.signature
        onSelection?(result)
    }

    private func readAccessibilitySelection() -> SelectionSnapshot? {
        let system = AXUIElementCreateSystemWide()
        var candidates: [AXUIElement] = []

        if let focused = copyElementAttribute(system, kAXFocusedUIElementAttribute as CFString) {
            candidates.append(focused)
        }

        if let location = CGEvent(source: nil)?.location {
            var pointed: AXUIElement?
            if AXUIElementCopyElementAtPosition(system, Float(location.x), Float(location.y), &pointed) == .success,
               let pointed {
                candidates.insert(pointed, at: 0)
            }
        }

        for initial in candidates {
            var element: AXUIElement? = initial
            for _ in 0..<8 {
                guard let current = element else { break }
                if let snapshot = snapshot(from: current) { return snapshot }
                element = copyElementAttribute(current, kAXParentAttribute as CFString)
            }
        }
        return nil
    }

    private func readClipboardSelection() async -> SelectionSnapshot? {
        let pasteboard = NSPasteboard.general
        let backup = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        sendCopyShortcut()
        try? await Task<Never, Never>.sleep(nanoseconds: 120_000_000)
        let selected = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        backup.restore(to: pasteboard)
        guard let selected, !selected.isEmpty, selected.count <= maximumCharacters else { return nil }
        return SelectionSnapshot(text: selected, screenRect: fallbackRectNearPointer())
    }

    private func sendCopyShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func snapshot(from element: AXUIElement) -> SelectionSnapshot? {
        guard let selected = copyAttribute(element, kAXSelectedTextAttribute as CFString) as? String else { return nil }
        let text = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maximumCharacters else { return nil }

        let fallback = fallbackRectNearPointer()
        guard let rawRangeValue = copyAttribute(element, kAXSelectedTextRangeAttribute as CFString),
              CFGetTypeID(rawRangeValue) == AXValueGetTypeID() else {
            return SelectionSnapshot(text: text, screenRect: fallback)
        }
        let rangeValue = unsafeDowncast(rawRangeValue, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else {
            return SelectionSnapshot(text: text, screenRect: fallback)
        }
        guard let parameter = AXValueCreate(.cfRange, &range) else {
            return SelectionSnapshot(text: text, screenRect: fallback)
        }
        var boundsValue: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            parameter,
            &boundsValue
        )
        guard status == .success, let rawBoundsValue = boundsValue,
              CFGetTypeID(rawBoundsValue) == AXValueGetTypeID() else {
            return SelectionSnapshot(text: text, screenRect: fallback)
        }
        let axValue = unsafeDowncast(rawBoundsValue, to: AXValue.self)
        var axRect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &axRect), !axRect.isEmpty else {
            return SelectionSnapshot(text: text, screenRect: fallback)
        }
        return SelectionSnapshot(text: text, screenRect: cocoaRect(fromAccessibilityRect: axRect))
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute, &value) == .success ? value : nil
    }

    private func copyElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func cocoaRect(fromAccessibilityRect rect: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.origin.x, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private func fallbackRectNearPointer() -> CGRect {
        let point = NSEvent.mouseLocation
        return CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
    }
}

@MainActor
private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        if !restoredItems.isEmpty { pasteboard.writeObjects(restoredItems) }
    }
}
