import SwiftUI
import AppKit

struct YAMLEditor: View {
    @Binding var text: String
    let font: Font
    
    @State private var lineCount: Int = 1
    @State private var textView: NSTextView?
    
    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            VStack {
                ForEach(0..<max(lineCount, 1), id: \.self) { line in
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
            
            // Editor with guides
            ZStack {
                IndentationGuides(text: text, font: font)
                
                TextEditor(text: $text)
                    .font(font)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
            }
        }
        .onChange(of: text) { _, newValue in
            updateLineCount(text: newValue)
        }
        .onAppear {
            configureTextView()
        }
    }
    
    private func updateLineCount(text: String) {
        lineCount = max(text.components(separatedBy: .newlines).count, 1)
    }
    
    private func configureTextView() {
        DispatchQueue.main.async {
            guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
            
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            
            textView.backgroundColor = .clear
            textView.drawsBackground = false
            
            self.textView = textView
        }
    }
}

struct IndentationGuides: View {
    let text: String
    let font: Font
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let spaceWidth: CGFloat = 7.2
                let lines = text.components(separatedBy: .newlines)
                let maxIndent = lines.map(calculateIndentLevel).max() ?? 0
                
                // Draw background
                let background = Path(CGRect(origin: .zero, size: size))
                context.fill(background, with: .color(Color(NSColor.textBackgroundColor)))
                
                if maxIndent > 0 {
                    for level in 1...maxIndent {
                        let x = CGFloat(level) * (spaceWidth * 2) + 4 // Added offset
                        
                        if lines.contains(where: { calculateIndentLevel($0) >= level }) {
                            let guide = Path { p in
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: size.height))
                            }
                            
                            // More visible guides with system accent color
                            context.stroke(
                                guide,
                                with: .color(Color.gray.opacity(0.3)),
                                style: StrokeStyle(
                                    lineWidth: 1,
                                    dash: [2, 4],
                                    dashPhase: 2
                                )
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func calculateIndentLevel(_ line: String) -> Int {
        let indentSize = 2
        let leadingSpaces = line.prefix { $0 == " " }.count
        return leadingSpaces / indentSize
    }
}

#Preview {
    YAMLEditor(text: .constant("key: value\nother:\n  nested: value\n  another: test"), font: .system(.body, design: .monospaced))
        .frame(width: 400, height: 300)
} 