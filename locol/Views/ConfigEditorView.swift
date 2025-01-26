//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI
import CodeEditor
import os

@Observable
final class ConfigEditorViewModel {
    var configText: String = ""
    var showingSnippetError = false
    var errorMessage = ""
    var previewSnippet: ConfigSnippet?
    
    private var originalConfig: String = ""
    private let snippetManager: ConfigSnippetManager
    private let appState: AppState
    private let collectorId: UUID
    
    init(appState: AppState, collectorId: UUID) {
        self.appState = appState
        self.collectorId = collectorId
        self.snippetManager = ConfigSnippetManager()
        loadConfig()
    }
    
    func loadConfig() {
        guard let collector = appState.collectors.first(where: { $0.id == collectorId }) else { return }
        
        do {
            let content = try String(contentsOfFile: collector.configPath, encoding: .utf8)
            configText = content
            originalConfig = content
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
            
            guard let collector = appState.collectors.first(where: { $0.id == collectorId }) else { return }
            try snippetManager.saveConfig(to: collector.configPath)
        } catch {
            errorMessage = "Failed to merge snippet: \(error.localizedDescription)"
            showingSnippetError = true
            configText = originalConfig
            previewSnippet = nil
        }
    }
    
    func saveConfig() {
        appState.updateCollectorConfig(withId: collectorId, config: configText)
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
    let appState: AppState
    let collectorId: UUID?
    @State private var viewModel: ConfigEditorViewModel?
    
    var collector: CollectorInstance? {
        guard let collectorId = collectorId else { return nil }
        return appState.collectors.first { $0.id == collectorId }
    }
    
    var body: some View {
        if let collector = collector {
            ConfigEditorContent(collector: collector, viewModel: viewModel ?? ConfigEditorViewModel(appState: appState, collectorId: collector.id))
                .onAppear {
                    if viewModel == nil {
                        viewModel = ConfigEditorViewModel(appState: appState, collectorId: collector.id)
                    }
                }
        } else {
            ContentUnavailableView {
                Label("No Collector Selected", systemImage: "square.dashed")
            } description: {
                Text("Select a collector to edit its configuration")
            }
        }
    }
}

private struct SnippetButton: View {
    let snippet: ConfigSnippet
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(snippet.name)
                        .font(.headline)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SnippetFooter: View {
    let onApply: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Button("Apply Snippet", action: onApply)
                .keyboardShortcut(.return, modifiers: .command)
            
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }
}

private struct SnippetPane: View {
    let snippets: [SnippetType: [ConfigSnippet]]
    let selectedSnippetId: UUID?
    let onSnippetSelected: (ConfigSnippet) -> Void
    let onApplySnippet: (() -> Void)?
    let onCancelPreview: (() -> Void)?
    
    var body: some View {
        VStack {
            List {
                ForEach(Array(snippets.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                    Section {
                        ForEach(snippets[type] ?? []) { snippet in
                            SnippetButton(
                                snippet: snippet,
                                isSelected: selectedSnippetId == snippet.id,
                                onTap: { onSnippetSelected(snippet) }
                            )
                        }
                    } header: {
                        ListSectionHeader(title: type.rawValue)
                    }
                }
            }
            
            if onApplySnippet != nil {
                SnippetFooter(
                    onApply: { onApplySnippet?() },
                    onCancel: { onCancelPreview?() }
                )
            }
        }
        .frame(minWidth: 250, maxWidth: 300)
    }
}

private struct EditorPane: View {
    @Binding var configText: String
    let onSave: () -> Void
    let onCancelPreview: (() -> Void)?
    
    var body: some View {
        VStack {
            CodeEditor(
                source: $configText,
                language: .yaml,
                theme: .ocean,
                autoPairs: ["(": ")", "[": "]", "{": "}", "\"": "\""]
            )
            .font(.system(.body, design: .monospaced))
            
            HStack {
                Button("Save", action: onSave)
                    .keyboardShortcut("s", modifiers: .command)
                
                if onCancelPreview != nil {
                    Button("Cancel Preview", action: { onCancelPreview?() })
                }
            }
            .padding()
        }
    }
}

private struct ConfigEditorContent: View {
    let collector: CollectorInstance
    @State var viewModel: ConfigEditorViewModel
    @State private var showingError = false
    
    var body: some View {
        HSplitView {
            EditorPane(
                configText: Binding(
                    get: { viewModel.configText },
                    set: { viewModel.configText = $0 }
                ),
                onSave: { viewModel.saveConfig() },
                onCancelPreview: viewModel.previewSnippet != nil ? { viewModel.cancelPreview() } : nil
            )
            
            SnippetPane(
                snippets: viewModel.snippets,
                selectedSnippetId: viewModel.previewSnippet?.id,
                onSnippetSelected: { viewModel.previewSnippetMerge($0) },
                onApplySnippet: viewModel.previewSnippet != nil ? { viewModel.mergeSnippet(viewModel.previewSnippet!) } : nil,
                onCancelPreview: viewModel.previewSnippet != nil ? { viewModel.cancelPreview() } : nil
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.showingSnippetError) {
            showingError = viewModel.showingSnippetError
        }
    }
}

#Preview {
    let appState = AppState()
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
    
    // Add mock collector to appState
    let collector = CollectorInstance(
        name: "Mock Collector",
        version: mockRelease.tagName,
        binaryPath: "/tmp/mock",
        configPath: "/tmp/mock.yaml"
    )
    appState.addCollector(collector)
    
    return ConfigEditorView(
        appState: appState,
        collectorId: mockCollectorId
    )
    .frame(width: 800, height: 600)
}
