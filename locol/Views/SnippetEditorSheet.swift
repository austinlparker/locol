import SwiftUI

enum SnippetEditorResult {
    case created(ConfigSnippet)
    case updated(ConfigSnippet)
    case deleted(ConfigSnippet)
    case cancelled
}

struct SnippetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var typeDefault: SnippetType
    @Binding var snippet: ConfigSnippet?
    var onComplete: (SnippetEditorResult) -> Void

    @State private var name: String = "new-snippet.yaml"
    @State private var type: SnippetType
    @State private var content: String = ""

    init(typeDefault: SnippetType, snippet: Binding<ConfigSnippet?>, onComplete: @escaping (SnippetEditorResult) -> Void) {
        self.typeDefault = typeDefault
        self._snippet = snippet
        self.onComplete = onComplete
        _type = State(initialValue: snippet.wrappedValue?.type ?? typeDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(snippet == nil ? "New Snippet" : "Edit Snippet")
                    .font(.title3.bold())
                Spacer()
            }

            Form {
                TextField("File name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(SnippetType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Text("Content (YAML)")
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 240)
            }

            HStack {
                if let existing = snippet {
                    Button("Delete", role: .destructive) { onComplete(.deleted(existing)); dismiss() }
                }
                Spacer()
                Button("Cancel") { onComplete(.cancelled); dismiss() }
                Button("Save") { save(); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            if let s = snippet {
                name = s.name
                type = s.type
                content = s.content
            }
        }
    }

    private func save() {
        let configuredName = name.isEmpty ? "snippet.yaml" : name
        let newSnippet = ConfigSnippet(name: configuredName, type: type, content: content)
        if snippet == nil { onComplete(.created(newSnippet)) }
        else { onComplete(.updated(newSnippet)) }
    }
}
