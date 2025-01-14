//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI

struct ConfigEditorView: View {
    @ObservedObject var manager: CollectorManager
    let collectorId: UUID
    
    @State private var configText: String = ""
    @State private var selectedTemplate: URL?
    @State private var showingTemplateAlert = false
    
    var body: some View {
        HSplitView {
            // Template List
            List(manager.listConfigTemplates(), id: \.self) { template in
                HStack {
                    Text(template.lastPathComponent)
                        .foregroundColor(selectedTemplate == template ? .accentColor : .primary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTemplate = template
                    showingTemplateAlert = true
                }
            }
            .frame(minWidth: 200, maxWidth: 300)
            .listStyle(SidebarListStyle())
            
            // Editor
            VStack {
                YAMLEditor(text: $configText, font: .custom("Menlo", size: 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack {
                    Spacer()
                    Button("Save") {
                        manager.updateCollectorConfig(withId: collectorId, config: configText)
                    }
                    .keyboardShortcut("s", modifiers: .command)
                }
                .padding()
            }
        }
        .alert("Apply Template", isPresented: $showingTemplateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                if let template = selectedTemplate {
                    manager.applyConfigTemplate(named: template.lastPathComponent, toCollectorWithId: collectorId)
                    loadConfig()
                }
            }
        } message: {
            Text("Are you sure you want to apply this template? This will overwrite your current configuration.")
        }
        .onAppear {
            loadConfig()
        }
    }
    
    private func loadConfig() {
        guard let collector = manager.collectors.first(where: { $0.id == collectorId }) else { return }
        do {
            configText = try manager.fileManager.readConfig(from: collector.configPath)
        } catch {
            AppLogger.shared.error("Failed to load config: \(error.localizedDescription)")
            configText = "# Failed to load configuration"
        }
    }
}
