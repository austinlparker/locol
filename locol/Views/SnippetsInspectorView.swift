import SwiftUI
import CoreTransferable

enum SnippetAction {
    case drag(ConfigSnippet)
    case create(ConfigSnippet)
    case update(ConfigSnippet)
    case delete(ConfigSnippet)
}

struct SnippetsInspectorView: View {
    let snippetManager: ConfigSnippetManaging
    var onAction: (SnippetAction) -> Void

    @State private var showEditor = false
    @State private var editing: ConfigSnippet? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Snippets").font(.headline)
                Spacer()
                Button { editing = nil; showEditor = true } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            List {
                ForEach(SnippetType.allCases, id: \.self) { type in
                    if let rows = snippetManager.snippets[type], !rows.isEmpty {
                        Section(header: Text(type.displayName)) {
                            ForEach(rows) { snippet in
                                SnippetRowView(snippet: snippet) {
                                    editing = snippet; showEditor = true
                                } onDelete: {
                                    onAction(.delete(snippet))
                                }
                                .draggable(snippet)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .sheet(isPresented: $showEditor) {
            SnippetEditorSheet(typeDefault: .receivers, snippet: $editing) { result in
                switch result {
                case .created(let s): onAction(.create(s))
                case .updated(let s): onAction(.update(s))
                case .deleted(let s): onAction(.delete(s))
                case .cancelled: break
                }
                // Dismiss and clear state after handling any action
                showEditor = false
                editing = nil
            }
            .frame(minWidth: 520, minHeight: 420)
        }
        .padding(.bottom, 8)
    }
}

private struct SnippetRowView: View {
    let snippet: ConfigSnippet
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type glyph for subtle categorization
            Circle().fill(typeColor).frame(width: 8, height: 8)

            Text(snippet.name)
                .font(.system(.body))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()

            Button(role: .none) { onEdit() } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .help("Edit Snippet")
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Delete Snippet")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var typeColor: Color {
        switch snippet.type {
        case .receivers: return .blue
        case .processors: return .orange
        case .exporters: return .purple
        }
    }
}
