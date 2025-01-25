import SwiftUI
import CodeEditor

struct ConfigEditor: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    @State private var configText: String = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            editor
        }
    }
    
    private var editorToolbar: some View {
        HStack {
            Spacer()
            Button(action: saveConfig) {
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
        CodeEditor(source: $configText, 
                  language: CodeEditor.Language.yaml, 
                  theme: colorScheme == .dark ? CodeEditor.ThemeName.ocean : CodeEditor.ThemeName.default,
                  flags: [CodeEditor.Flags.selectable, CodeEditor.Flags.editable, CodeEditor.Flags.smartIndent],
                  indentStyle: CodeEditor.IndentStyle.softTab(width: 2),
                  autoPairs: [:])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                do {
                    configText = try String(contentsOfFile: collector.configPath, encoding: .utf8)
                } catch {
                    print("Error loading config: \(error)")
                }
            }
    }
    
    private func saveConfig() {
        do {
            try configText.write(toFile: collector.configPath, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving config: \(error)")
        }
    }
} 
