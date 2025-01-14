import SwiftUI

struct YAMLEditor: View {
    @Binding var text: String
    let font: Font
    
    @State private var lineCount: Int = 0
    
    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            VStack {
                ForEach(0..<lineCount, id: \.self) { line in
                    Text("\(line + 1)")
                        .font(font)
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                        .padding(.trailing, 8)
                }
                Spacer()
            }
            .padding(.top, 8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            
            // Editor
            TextEditor(text: $text)
                .font(font)
                .onChange(of: text) { newValue in
                    updateLineCount(text: newValue)
                }
                .onAppear {
                    updateLineCount(text: text)
                }
        }
    }
    
    private func updateLineCount(text: String) {
        lineCount = text.components(separatedBy: .newlines).count
    }
}

#Preview {
    YAMLEditor(text: .constant("key: value\nother: value"), font: .custom("Menlo", size: 12))
        .frame(width: 400, height: 300)
} 