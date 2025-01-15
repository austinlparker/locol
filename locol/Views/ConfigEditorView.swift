//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI

struct SidebarSectionHeader: View {
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
    @ObservedObject var manager: CollectorManager
    @StateObject private var snippetManager = ConfigSnippetManager()
    let collectorId: UUID
    
    @State private var configText: String = ""
    @State private var showingSnippetError = false
    @State private var errorMessage = ""
    @State private var previewSnippet: ConfigSnippet?
    @State private var originalConfig: String = ""
    
    var body: some View {
        HSplitView {
            // Left sidebar with snippets
            VStack(spacing: 0) {
                List {
                    ForEach(SnippetType.allCases, id: \.self) { type in
                        Section {
                            if let snippetsForType = snippetManager.snippets[type], !snippetsForType.isEmpty {
                                ForEach(snippetsForType) { snippet in
                                    HStack {
                                        Text(snippet.name)
                                            .font(.system(.body))
                                        Spacer()
                                        if previewSnippet?.id == snippet.id {
                                            Button(action: {
                                                mergeSnippet(snippet)
                                                previewSnippet = nil
                                            }) {
                                                Label("Apply", systemImage: "plus.circle.fill")
                                            }
                                            .buttonStyle(.borderless)
                                            .labelStyle(.iconOnly)
                                            .help("Apply snippet")
                                            
                                            Button(action: {
                                                configText = originalConfig
                                                previewSnippet = nil
                                            }) {
                                                Label("Cancel", systemImage: "xmark.circle.fill")
                                            }
                                            .buttonStyle(.borderless)
                                            .labelStyle(.iconOnly)
                                            .help("Cancel preview")
                                        } else {
                                            Label("Preview", systemImage: "plus.circle")
                                                .labelStyle(.iconOnly)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        previewSnippetMerge(snippet)
                                    }
                                }
                            } else {
                                Text("No snippets available")
                                    .font(.system(.body))
                                    .foregroundStyle(.secondary)
                            }
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
            
            // Editor
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    if previewSnippet != nil {
                        Label("Preview Mode", systemImage: "eye")
                            .font(.system(.body))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        manager.updateCollectorConfig(withId: collectorId, config: configText)
                    }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Editor with line numbers
                YAMLEditor(text: $configText, font: .system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Error", isPresented: $showingSnippetError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadConfig()
        }
    }
    
    private func loadConfig() {
        guard let collector = manager.collectors.first(where: { $0.id == collectorId }) else { return }
        
        do {
            let content = try String(contentsOfFile: collector.configPath, encoding: .utf8)
            configText = content
            originalConfig = content
            
            // Also load into snippet manager for merging
            snippetManager.loadConfig(from: collector.configPath)
        } catch {
            AppLogger.shared.error("Failed to load config: \(error.localizedDescription)")
            // Set empty config to avoid null issues
            configText = ""
            originalConfig = ""
        }
    }
    
    private func previewSnippetMerge(_ snippet: ConfigSnippet) {
        if previewSnippet?.id == snippet.id {
            // If clicking the same snippet again, cancel preview
            configText = originalConfig
            previewSnippet = nil
            return
        }
        
        // Store original config if this is the first preview
        if previewSnippet == nil {
            originalConfig = configText
        }
        
        // Show preview
        if let currentConfig = snippetManager.currentConfig {
            configText = snippetManager.previewSnippetMerge(snippet, into: currentConfig)
            previewSnippet = snippet
        }
    }
    
    private func mergeSnippet(_ snippet: ConfigSnippet) {
        do {
            try snippetManager.mergeSnippet(snippet)
            if let preview = snippetManager.previewConfig {
                configText = preview
                originalConfig = preview
            }
            previewSnippet = nil
            
            // Save to disk
            guard let collector = manager.collectors.first(where: { $0.id == collectorId }) else { return }
            try snippetManager.saveConfig(to: collector.configPath)
        } catch {
            errorMessage = "Failed to merge snippet: \(error.localizedDescription)"
            showingSnippetError = true
            // Revert to original on error
            configText = originalConfig
            previewSnippet = nil
        }
    }
}
