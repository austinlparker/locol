//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI
import Yams
import STTextViewSwiftUI
import UniformTypeIdentifiers
import os
import Observation

@MainActor
@Observable
class ConfigEditorViewModel {
    var configText: String = ""
    var showingSnippetError = false
    var errorMessage = ""
    var previewSnippet: ConfigSnippet?
    
    private var originalConfig: String = ""
    let snippetManager: ConfigSnippetManaging
    let manager: CollectorManager
    let collectorId: UUID
    
    init(manager: CollectorManager, collectorId: UUID, snippetManager: ConfigSnippetManaging) {
        self.manager = manager
        self.collectorId = collectorId
        self.snippetManager = snippetManager
    }
    
    func loadConfig() {
        guard let collector = manager.collectors.first(where: { $0.id == collectorId }) else { return }
        
        do {
            let content = try String(contentsOfFile: collector.configPath, encoding: .utf8)
            configText = content
            originalConfig = content
            
            // Load config for snippet functionality synchronously to avoid concurrency issues
            snippetManager.loadConfig(from: collector.configPath)
        } catch {
            handleError(error)
            configText = snippetManager.defaultTemplate
            originalConfig = configText
        }
    }
    
    func previewSnippetMerge(_ snippet: ConfigSnippet) {
        if previewSnippet?.id == snippet.id {
            configText = originalConfig
            previewSnippet = nil
            return
        }
        
        if previewSnippet == nil {
            originalConfig = configText
        }
        
        if let currentConfig = snippetManager.currentConfig {
            configText = snippetManager.previewSnippetMerge(snippet, into: currentConfig)
            previewSnippet = snippet
        }
    }
    
    func mergeSnippet(_ snippet: ConfigSnippet) {
        do {
            try snippetManager.mergeSnippet(snippet)
            if let preview = snippetManager.previewConfig {
                configText = preview
                originalConfig = preview
            }
            previewSnippet = nil
            
            guard let collector = manager.collectors.first(where: { $0.id == collectorId }) else { return }
            try snippetManager.saveConfig(to: collector.configPath)
        } catch {
            errorMessage = "Failed to merge snippet: \(error.localizedDescription)"
            showingSnippetError = true
            configText = originalConfig
            previewSnippet = nil
        }
    }
    
    func saveConfig() {
        manager.updateCollectorConfig(withId: collectorId, config: configText)
    }
    
    func cancelPreview() {
        configText = originalConfig
        previewSnippet = nil
    }
    
    var snippets: [SnippetType: [ConfigSnippet]] {
        snippetManager.snippets
    }
    
    private func handleError(_ error: Error) {
        Logger.app.error("Failed to load config: \(error.localizedDescription)")
        configText = snippetManager.defaultTemplate
        originalConfig = configText
    }

    // MARK: - Snippet CRUD passthrough
    func createSnippet(_ snippet: ConfigSnippet) throws { try snippetManager.createSnippet(snippet) }
    func updateSnippet(_ snippet: ConfigSnippet) throws { try snippetManager.updateSnippet(snippet) }
    func deleteSnippet(_ snippet: ConfigSnippet) throws { try snippetManager.deleteSnippet(snippet) }
    func reloadSnippets() { snippetManager.reloadSnippets() }
}

struct ListSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
    }
}

struct ConfigEditorView: View {
    @State private var viewModel: ConfigEditorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var attributedText: AttributedString = ""
    @State private var selection: NSRange?
    @State private var font = Font.system(size: 13, design: .monospaced)
    @State private var pendingAddedLines = IndexSet()
    
    init(manager: CollectorManager, collectorId: UUID, snippetManager: ConfigSnippetManaging) {
        _viewModel = State(wrappedValue: ConfigEditorViewModel(manager: manager, collectorId: collectorId, snippetManager: snippetManager))
    }
    
    var body: some View {
        // Just the editor - tabs are handled at DetailView level
        editorStack
        .alert("Error", isPresented: $viewModel.showingSnippetError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: formatYAML) { Label("Format", systemImage: "wand.and.stars") }
                Button(action: { viewModel.saveConfig(); clearPending() }) { Label("Save", systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("s", modifiers: .command)
            }
        }
        .onAppear {
            viewModel.loadConfig()
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let attrs = AttributeContainer([.foregroundColor: NSColor.labelColor, .font: font])
            attributedText = AttributedString(viewModel.configText, attributes: attrs)
        }
        .onChange(of: viewModel.configText) { _, _ in
            refreshAttributedText(highlightingLines: pendingAddedLines)
        }
    }
    
    // Snippet integration for drag operations - action handlers will be provided by parent view
    func onSnippetAction(_ action: SnippetAction) {
        switch action {
        case .drag(let snippet):
            insertPreviewSnippet(name: snippet.name, type: snippet.type, content: snippet.content)
        case .create(let snippet):
            try? viewModel.createSnippet(snippet)
        case .update(let snippet):
            try? viewModel.updateSnippet(snippet)
        case .delete(let snippet):
            try? viewModel.deleteSnippet(snippet)
        }
        viewModel.reloadSnippets()
    }
    
    private var editorStack: some View {
        VStack(spacing: 0) {
            editor
        }
    }
    
    private var editor: some View {
        ZStack {
            TextView(
                text: Binding<AttributedString>(
                    get: { attributedText },
                    set: { newValue in
                        attributedText = newValue
                        viewModel.configText = String(newValue.characters)
                    }
                ),
                selection: $selection,
                options: [.wrapLines, .highlightSelectedLine, .showLineNumbers]
            )
            .textViewFont(NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))

            // Transparent drop catcher overlay to avoid NSTextView consuming the drop
            DropCatcherView(
                acceptedTypes: [.data, .utf8PlainText, .plainText]
            ) { pasteboard in
                // Attempt to decode a snippet from any data-backed type
                if let types = pasteboard.types {
                    for t in types {
                        if let data = pasteboard.data(forType: t) {
                            // Try Codable snippet first
                            if let decoded = try? JSONDecoder().decode(ConfigSnippet.self, from: data) {
                                insertPreviewSnippet(name: decoded.name, type: decoded.type, content: decoded.content)
                                return true
                            }
                            // Try basic JSON dictionary
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let name = json["name"] as? String,
                               let typeRaw = json["type"] as? String,
                               let content = json["content"] as? String,
                               let type = SnippetType(rawValue: typeRaw) {
                                insertPreviewSnippet(name: name, type: type, content: content)
                                return true
                            }
                        }
                    }
                }

                // Fallback: plain text paste (YAML). Auto-detect type key.
                if let str = pasteboard.string(forType: .string) ?? pasteboard.string(forType: .init("public.utf8-plain-text")) {
                    let detectedType: SnippetType = {
                        if let dict = try? Yams.load(yaml: str) as? [String: Any] {
                            for t in SnippetType.allCases { if dict[t.rawValue] != nil { return t } }
                        }
                        return .receivers
                    }()
                    insertPreviewSnippet(name: "Dropped Snippet", type: detectedType, content: str)
                    return true
                }
                return false
            }
            .ignoresSafeArea()
            // Overlay must be hittable for drag; hitTest is customized to pass clicks through
            .opacity(0.001)
        }
        // SwiftUI onDrop as primary path; overlay is a fallback visual layer
        .dropDestination(for: ConfigSnippet.self) { items, _ in
            guard let first = items.first else { return false }
            insertPreviewSnippet(name: first.name, type: first.type, content: first.content)
            return true
        }
        .onDrop(of: [UTType.utf8PlainText, .plainText], isTargeted: nil) { providers in
            // Try custom snippet payload first
            if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) || $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
                    guard let data, let str = String(data: data, encoding: .utf8) else { return }
                    let detectedType: SnippetType = {
                        if let dict = try? Yams.load(yaml: str) as? [String: Any] {
                            for t in SnippetType.allCases { if dict[t.rawValue] != nil { return t } }
                        }
                        return .receivers
                    }()
                    Task { @MainActor in insertPreviewSnippet(name: "Dropped Snippet", type: detectedType, content: str) }
                }
                return true
            }
            return false
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Formatting Helper
extension ConfigEditorView {
    private func formatYAML() {
        do {
            if let yaml = try? Yams.load(yaml: viewModel.configText),
               let dict = yaml as? [String: Any] {
                let pretty = try Yams.dump(object: dict)
                viewModel.configText = pretty
            }
        } catch {
            // Ignore formatting errors silently for now
        }
    }
    
    // No manual caret insertion required; STTextViewSwiftUI binding updates text
    private func insertPreviewSnippet(name: String, type: SnippetType, content: String) {
        let snippet = ConfigSnippet(name: name, type: type, content: content)
        let before = viewModel.configText
        viewModel.previewSnippetMerge(snippet)
        let after = viewModel.configText
        pendingAddedLines = computeAddedLineIndices(original: before, new: after)
        refreshAttributedText(highlightingLines: pendingAddedLines)
    }

    private func computeAddedLineIndices(original: String, new: String) -> IndexSet {
        let a = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let b = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let n = a.count, m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0..<n {
            for j in 0..<m {
                dp[i+1][j+1] = (a[i] == b[j]) ? dp[i][j] + 1 : max(dp[i][j+1], dp[i+1][j])
            }
        }
        var i = n, j = m
        var inLCS = Array(repeating: false, count: m)
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] { inLCS[j-1] = true; i -= 1; j -= 1 }
            else if dp[i-1][j] >= dp[i][j-1] { i -= 1 } else { j -= 1 }
        }
        var added = IndexSet()
        for idx in 0..<m { if !inLCS[idx] { added.insert(idx) } }
        return added
    }

    private func refreshAttributedText(highlightingLines: IndexSet) {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        var result = AttributedString("")
        let lines = viewModel.configText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (idx, line) in lines.enumerated() {
            var attrs = AttributeContainer([.foregroundColor: NSColor.labelColor, .font: font])
            if highlightingLines.contains(idx) {
                attrs.merge(AttributeContainer([.backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.22)]))
            }
            let suffix = (idx < lines.count - 1) ? "\n" : ""
            result += AttributedString(line + suffix, attributes: attrs)
        }
        attributedText = result
    }

    private func clearPending() {
        pendingAddedLines = []
        refreshAttributedText(highlightingLines: [])
    }
}
