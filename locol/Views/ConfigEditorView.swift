//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI
import CodeEditor

@MainActor
class ConfigEditorViewModel: ObservableObject {
    @Published var configText: String = ""
    @Published var showingSnippetError = false
    @Published var errorMessage = ""
    @Published var previewSnippet: ConfigSnippet?
    
    private var originalConfig: String = ""
    private let snippetManager: ConfigSnippetManager
    private let manager: CollectorManager
    private let collectorId: UUID
    
    init(manager: CollectorManager, collectorId: UUID) {
        self.manager = manager
        self.collectorId = collectorId
        self.snippetManager = ConfigSnippetManager()
        loadConfig()
    }
    
    func loadConfig() {
        guard let collector = manager.collectors.first(where: { $0.id == collectorId }) else { return }
        
        do {
            let content = try String(contentsOfFile: collector.configPath, encoding: .utf8)
            configText = content
            originalConfig = content
            snippetManager.loadConfig(from: collector.configPath)
        } catch {
            AppLogger.shared.error("Failed to load config: \(error.localizedDescription)")
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
    @StateObject private var viewModel: ConfigEditorViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    init(manager: CollectorManager, collectorId: UUID) {
        _viewModel = StateObject(wrappedValue: ConfigEditorViewModel(manager: manager, collectorId: collectorId))
    }
    
    var body: some View {
        HSplitView {
            snippetsSidebar
            editorStack
        }
        .alert("Error", isPresented: $viewModel.showingSnippetError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var snippetsSidebar: some View {
        VStack(spacing: 0) {
            List {
                ForEach(SnippetType.allCases, id: \.self) { type in
                    Section {
                        snippetContent(for: type)
                    } header: {
                        Text(type.displayName)
                            .font(.system(.callout, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 220, maxWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func snippetContent(for type: SnippetType) -> some View {
        Group {
            if let snippetsForType = viewModel.snippets[type], !snippetsForType.isEmpty {
                ForEach(snippetsForType) { snippet in
                    snippetRow(snippet)
                }
            } else {
                Text("No snippets available")
                    .font(.system(.body))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func snippetRow(_ snippet: ConfigSnippet) -> some View {
        HStack {
            Text(snippet.name)
                .font(.system(.body))
                .truncationMode(.middle)
            Spacer()
            
            HStack(spacing: 8) {
                if viewModel.previewSnippet?.id == snippet.id {
                    Button(action: { viewModel.mergeSnippet(snippet) }) {
                        Label("Apply", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .labelStyle(.iconOnly)
                    .help("Apply snippet")
                    .tint(.accentColor)
                    
                    Button(action: { viewModel.cancelPreview() }) {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .labelStyle(.iconOnly)
                    .help("Cancel preview")
                    .tint(.secondary)
                } else {
                    Button(action: { viewModel.previewSnippetMerge(snippet) }) {
                        Label("Preview", systemImage: "eye.circle")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Preview snippet")
                }
            }
        }
        .contentShape(Rectangle())
    }
    
    private var editorStack: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            editor
        }
    }
    
    private var editorToolbar: some View {
        HStack {
            if viewModel.previewSnippet != nil {
                Label("Preview Mode", systemImage: "eye")
                    .font(.system(.body))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { viewModel.saveConfig() }) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var editor: some View {
        CodeEditor(source: $viewModel.configText, 
                  language: .yaml, 
                  theme: colorScheme == .dark ? .ocean : .default,
                  flags: [.selectable, .editable, .smartIndent],
                  indentStyle: .softTab(width: 2),
                  autoPairs: [:])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let mockManager = CollectorManager()
    let mockCollectorId = UUID()
    
    // Create mock release data
    let mockAsset = ReleaseAsset(
        url: "https://example.com",
        id: 1,
        name: "mock-collector",
        contentType: "application/octet-stream",
        size: 1000,
        downloadCount: 0,
        browserDownloadURL: "https://example.com/download"
    )
    
    let mockRelease = Release(
        url: "https://example.com",
        htmlURL: "https://example.com",
        assetsURL: "https://example.com/assets",
        tagName: "v1.0.0",
        name: "Release v1.0.0",
        publishedAt: "2024-03-17",
        author: nil,
        assets: [mockAsset]
    )
    
    try? mockManager.addCollector(
        name: "Mock Collector",
        version: mockRelease.tagName,
        release: mockRelease,
        asset: mockAsset
    )
    
    return ConfigEditorView(
        manager: mockManager,
        collectorId: mockCollectorId
    )
    .frame(width: 800, height: 600)
}
