import AppKit
import ApplicationServices
import Combine
import SwiftUI

struct BubbleView: View {
    let scale: Double
    let theme: GlassTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 38 * scale, height: 38 * scale)
                .shadow(color: theme.accent.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("翻译所选文本")
        .padding(8)
    }
}

@MainActor
final class TranslationViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case result(String)
        case failure(String)
    }

    @Published var source = ""
    @Published var state: State = .loading
}

struct TranslationCardView: View {
    @ObservedObject var model: TranslationViewModel
    @ObservedObject var settings: SettingsStore
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WindowDragHandle()
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            if settings.showSourceText {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("原文").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button {
                            copyToPasteboard(model.source)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("复制原文")
                    }
                    Text(model.source)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                Divider().opacity(0.45)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("译文").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                content
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .padding(.trailing, 24)
        .frame(width: 390, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [.white.opacity(0.24), .clear, settings.glassTheme.accent.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.28), lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(.white.opacity(0.12)))
            .padding(10)
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("正在翻译…").foregroundStyle(.secondary)
            }
        case let .result(text):
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    Text(text)
                        .font(.system(size: settings.translationFontSize, weight: .medium))
                        .lineSpacing(-2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button {
                        copyToPasteboard(text)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }
        case let .failure(message):
            VStack(alignment: .leading, spacing: 12) {
                Text(message).foregroundStyle(.red)
                Button("重试", action: retry).buttonStyle(.bordered)
            }
        }
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

private final class DragHandleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.26).cgColor
        layer?.cornerRadius = 2.5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

private extension GlassTheme {
    var accent: Color {
        switch self {
        case .system: .accentColor
        case .frost: .cyan
        case .midnight: .indigo
        case .aurora: .purple
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let onSave: (String?) -> Void
    let openAccessibility: () -> Void

    private enum Section: String, CaseIterable, Identifiable {
        case selection = "划词"
        case translation = "翻译"
        case bubble = "气泡"
        case appearance = "外观"
        case startup = "启动"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .selection: "text.cursor"
            case .translation: "character.book.closed"
            case .bubble: "bubble.left.and.bubble.right"
            case .appearance: "paintpalette"
            case .startup: "power"
            }
        }
    }

    @State private var selectedSection: Section = .selection
    @State private var message = ""

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 9))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.purple.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wonder").font(.headline)
                    }
                }
                .padding(.bottom, 8)

                ForEach(Section.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon).frame(width: 18)
                            Text(section.rawValue)
                            Spacer()
                        }
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedSection == section ? Color.accentColor.opacity(0.16) : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(settings.isPaused ? .orange : .green).frame(width: 7, height: 7)
                    Text(settings.isPaused ? "监听已暂停" : "后台监听中").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(width: 190)
            .background(.thinMaterial)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(selectedSection.rawValue)
                            .font(.system(size: 24, weight: .semibold))
                        sectionContent
                    }
                    .padding(26)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                HStack {
                    Text(message).font(.caption).foregroundStyle(message.contains("失败") ? .red : .secondary)
                    Spacer()
                    Button("恢复推荐设置") { restoreRecommendedSettings() }
                    Button("保存设置") {
                        do {
                            try settings.save()
                            message = "设置已保存"
                            onSave(nil)
                        } catch {
                            message = "保存失败：\(error.localizedDescription)"
                            onSave(message)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 24)
                .frame(height: 58)
            }
        }
        .frame(width: 760, height: 540)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(colors: [.white.opacity(0.16), .clear, .purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .selection:
            GroupBox("监听方式") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("启用划词监听", isOn: Binding(
                        get: { !settings.isPaused },
                        set: { settings.isPaused = !$0 }
                    ))
                    Picker("选区读取", selection: $settings.selectionMethod) {
                        ForEach(SelectionMethod.allCases) { Text($0.title).tag($0) }
                    }
                    Text("自动兼容会优先读取辅助功能，失败后短暂复制所选文本并完整恢复原剪贴板。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("响应延迟")
                        Slider(value: $settings.selectionDelay, in: 0.08...0.60, step: 0.02)
                        Text("\(Int(settings.selectionDelay * 1000)) ms").monospacedDigit().frame(width: 58)
                    }
                }.padding(8)
            }
            GroupBox("系统权限") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: settings.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(settings.accessibilityGranted ? .green : .orange)
                        Text(settings.accessibilityGranted ? "辅助功能权限已开启" : "当前运行的 Wonder 未获得辅助功能权限")
                        Spacer()
                        Button("打开系统设置", action: openAccessibility)
                    }
                    if !settings.accessibilityGranted {
                        Text("若系统开关已开启，请删除旧 Wonder 条目，再用“+”添加下面这份应用。")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(Bundle.main.bundleURL.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }.padding(8)
            }
        case .translation:
            GroupBox("翻译服务") {
                VStack(alignment: .leading, spacing: 14) {
                    Label("免费翻译（无需密钥）", systemImage: "gift")
                    Picker("目标语言", selection: $settings.targetLanguage) {
                        ForEach(TargetLanguage.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("联系邮箱（选填，可提升免费额度）", text: $settings.freeServiceEmail)
                        .textFieldStyle(.roundedBorder)
                    Text("匿名每天 5,000 字符；填写有效邮箱后每天 50,000 字符。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
        case .bubble:
            GroupBox("气泡行为") {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("出现位置", selection: $settings.bubblePosition) {
                        ForEach(BubblePosition.allCases) { Text($0.title).tag($0) }
                    }
                    HStack {
                        Text("气泡大小")
                        Slider(value: $settings.bubbleScale, in: 0.80...1.50, step: 0.05)
                        Text("\(Int(settings.bubbleScale * 100))%").monospacedDigit().frame(width: 48)
                    }
                    HStack {
                        Spacer()
                        BubbleView(scale: settings.bubbleScale, theme: settings.glassTheme, action: {})
                        Spacer()
                    }.frame(height: 74)
                }.padding(8)
            }
        case .appearance:
            GroupBox("翻译卡片") {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("玻璃主题", selection: $settings.glassTheme) {
                        ForEach(GlassTheme.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("显示原文", isOn: $settings.showSourceText)
                    HStack {
                        Text("译文字号")
                        Slider(value: $settings.translationFontSize, in: 13...22, step: 1)
                        Text("\(Int(settings.translationFontSize)) pt").monospacedDigit().frame(width: 48)
                    }
                }.padding(8)
            }
        case .startup:
            GroupBox("后台运行") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("登录后自动启动", isOn: $settings.launchAtLogin)
                    Label("应用关闭设置窗口后仍会在菜单栏后台运行。", systemImage: "menubar.rectangle")
                        .font(.caption).foregroundStyle(.secondary)
                    Label("不会保存翻译历史；只有点击气泡后才把选中文本发送到翻译服务。", systemImage: "hand.raised")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
        }
    }

    private var canSave: Bool {
        true
    }

    private func restoreRecommendedSettings() {
        settings.selectionMethod = .automatic
        settings.selectionDelay = 0.18
        settings.bubbleScale = 1.0
        settings.bubblePosition = .below
        settings.glassTheme = .aurora
        settings.translationFontSize = 16
        settings.showSourceText = true
        message = "已恢复推荐值，点击保存生效"
    }
}
