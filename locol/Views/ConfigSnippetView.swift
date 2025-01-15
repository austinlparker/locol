import SwiftUI

struct ConfigSnippetView: View {
    @ObservedObject var snippetManager: ConfigSnippetManager
    var onSnippetSelected: (ConfigSnippet) -> Void
    
    var body: some View {
        List {
            ForEach(SnippetType.allCases, id: \.self) { type in
                Section(header: Text(type.displayName)) {
                    if let snippetsForType = snippetManager.snippets[type] {
                        ForEach(snippetsForType) { snippet in
                            HStack {
                                Text(snippet.name)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.accentColor)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSnippetSelected(snippet)
                            }
                        }
                    } else {
                        Text("No snippets available")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
} 