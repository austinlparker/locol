//
//  ConfigEditorView.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import SwiftUI

struct ConfigEditorView: View {
    @ObservedObject var manager: CollectorManager
    @State private var configText: String = ""

    var body: some View {
        VStack {
            TextEditor(text: $configText)
            
                .padding()
                .border(Color.gray)
                .onAppear {
                    // Load existing config
                    loadConfig()
                }

            Button("Save") {
                manager.writeConfig(configText)
            }
        }
        
        .frame(width: 400, height: 300)
        .padding()
        
    }

    func loadConfig() {
        let configPath = manager.collectorPath.appendingPathComponent("config.yaml")
        if let config = try? String(contentsOf: configPath, encoding: String.Encoding.utf8) {
            configText = config
        } else {
            configText = "default: {}" // Fallback to default
        }
    }
}
