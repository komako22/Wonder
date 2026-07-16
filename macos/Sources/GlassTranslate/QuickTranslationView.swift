import AppKit
import SwiftUI

@MainActor
final class QuickTranslationViewModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var sourceLanguage: SourceLanguage = .automatic
    @Published var targetLanguage: TargetLanguage = .simplifiedChinese
    @Published var isTranslating = false
    @Published var errorMessage = ""
}

struct QuickTranslationView: View {
    @ObservedObject var model: QuickTranslationViewModel
    let scheduleTranslation: () -> Void
    let close: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            languageBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            editors
                .padding(.horizontal, 20)
            footer
                .padding(20)
        }
        .frame(width: 680, height: 430)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [.white.opacity(0.20), .clear, .purple.opacity(0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .onAppear {
            DispatchQueue.main.async { inputFocused = true }
        }
        .onChange(of: model.input) { _ in scheduleTranslation() }
        .onChange(of: model.sourceLanguage) { _ in scheduleTranslation() }
        .onChange(of: model.targetLanguage) { _ in scheduleTranslation() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Text("翻译")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(.white.opacity(0.13)))
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
    }

    private var languageBar: some View {
        HStack(spacing: 12) {
            Picker("源语言", selection: $model.sourceLanguage) {
                ForEach(SourceLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.sourceLanguage == .automatic ? .tertiary : .secondary)
            .disabled(model.sourceLanguage == .automatic)
            .help("交换语言")

            Picker("目标语言", selection: $model.targetLanguage) {
                ForEach(TargetLanguage.quickTranslationChoices) { language in
                    Text(language.title).tag(language)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }

    private var editors: some View {
        HStack(spacing: 12) {
            editorCard(title: "原文") {
                ZStack(alignment: .topLeading) {
                    if model.input.isEmpty {
                        Text("输入要翻译的文字…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $model.input)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .focused($inputFocused)
                }
            }

            editorCard(title: "译文") {
                ScrollView {
                    Group {
                        if model.output.isEmpty {
                            Text(model.isTranslating ? "正在翻译…" : "译文将在这里显示")
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(model.output)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.system(size: 15))
                    .lineSpacing(-1)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(5)
                }
            }
        }
        .frame(height: 245)
    }

    private func editorCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if title == "译文", !model.output.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.output, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("复制译文")
                }
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.11)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.20), lineWidth: 0.8))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("清空") {
                model.input = ""
                model.output = ""
                model.errorMessage = ""
                inputFocused = true
            }
            .buttonStyle(.borderless)
            .disabled(model.input.isEmpty && model.output.isEmpty)

            Text("\(model.input.count) 字符")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if !model.errorMessage.isEmpty {
                Text(model.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 7) {
                if model.isTranslating {
                    ProgressView().controlSize(.small)
                    Text("自动翻译中…")
                } else {
                    Text("输入后自动翻译")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func swapLanguages() {
        guard let newSource = sourceLanguage(for: model.targetLanguage),
              let newTarget = targetLanguage(for: model.sourceLanguage) else { return }
        model.sourceLanguage = newSource
        model.targetLanguage = newTarget
        if !model.output.isEmpty {
            let previousInput = model.input
            model.input = model.output
            model.output = previousInput
        }
    }

    private func sourceLanguage(for target: TargetLanguage) -> SourceLanguage? {
        switch target {
        case .automatic: nil
        case .simplifiedChinese: .simplifiedChinese
        case .traditionalChinese: .traditionalChinese
        case .english: .englishUS
        case .englishUK: .englishUK
        case .japanese: .japanese
        case .korean: .korean
        case .french: .french
        case .german: .german
        case .spanish: .spanish
        case .russian: .russian
        case .italian: .italian
        case .portuguese: .portuguese
        }
    }

    private func targetLanguage(for source: SourceLanguage) -> TargetLanguage? {
        switch source {
        case .automatic: nil
        case .simplifiedChinese: .simplifiedChinese
        case .traditionalChinese: .traditionalChinese
        case .englishUS: .english
        case .englishUK: .englishUK
        case .japanese: .japanese
        case .korean: .korean
        case .french: .french
        case .german: .german
        case .spanish: .spanish
        case .russian: .russian
        case .italian: .italian
        case .portuguese: .portuguese
        }
    }
}
