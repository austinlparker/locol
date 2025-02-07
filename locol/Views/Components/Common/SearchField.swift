import SwiftUI
import Combine

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSearch: (String) -> Void
    
    @State private var searchTask: DispatchWorkItem?
    
    init(text: Binding<String>, placeholder: String = "Search...", onSearch: @escaping (String) -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.onSearch = onSearch
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onChange(of: text) { newValue in
                    // Cancel previous search task if any
                    searchTask?.cancel()
                    
                    // Create new search task
                    let task = DispatchWorkItem {
                        onSearch(newValue)
                    }
                    searchTask = task
                    
                    // Schedule the task with delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                }
            
            if !text.isEmpty {
                Button {
                    text = ""
                    onSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
    }
} 