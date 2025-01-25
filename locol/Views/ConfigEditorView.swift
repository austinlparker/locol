//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI
import CodeEditor
import os

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
    let manager: CollectorManager
    let collectorId: UUID?
    
    var collector: CollectorInstance? {
        guard let collectorId = collectorId else { return nil }
        return manager.collectors.first { $0.id == collectorId }
    }
    
    var body: some View {
        if let collector = collector {
            ConfigEditor(collector: collector, manager: manager)
        } else {
            ContentUnavailableView {
                Label("No Collector Selected", systemImage: "square.dashed")
            } description: {
                Text("Select a collector to edit its configuration")
            }
        }
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
    
    mockManager.addCollector(
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
