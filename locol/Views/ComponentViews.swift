import SwiftUI

struct CollectorComponent: Identifiable {
    let name: String
    let module: String
    
    var id: String { name }
}

struct ComponentSection: View {
    let title: String
    let components: [CollectorComponent]
    let version: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(components.sorted(by: { $0.name < $1.name })) { component in
                    ComponentTag(
                        name: component.name,
                        module: component.module,
                        version: version,
                        color: color
                    )
                }
            }
        }
    }
}

struct ComponentTag: View {
    let name: String
    let module: String
    let version: String
    let color: Color
    @Environment(\.openURL) private var openURL
    
    private var moduleUrl: URL? {
        if module.hasPrefix("github.com") {
            // Split the module path and remove version info
            let moduleWithoutVersion = module.split(separator: " ")[0]
            let parts = moduleWithoutVersion.split(separator: "/")
            
            if parts.count >= 4 {
                let org = "open-telemetry"  // Always use open-telemetry org
                let repo = "opentelemetry-collector-contrib"  // Always use contrib repo
                
                // Get the component path (type + name)
                let remainingPath = parts[3...].joined(separator: "/")
                
                // Construct GitHub URL with version
                let urlString = "https://github.com/\(org)/\(repo)/tree/\(version)/\(remainingPath)"
                return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
            }
        } else {
            // If not GitHub or invalid format, try as direct URL
            // Strip version info if present
            let urlString = module.split(separator: " ").first.map(String.init) ?? module
            return URL(string: "https://\(urlString)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
        }
        return nil
    }
    
    var body: some View {
        if let url = moduleUrl {
            Button {
                openURL(url) { success in
                    if success {
                        // Successfully opened URL
                    } else {
                        // Failed to open URL
                    }
                }
            } label: {
                TagContent(name: name, color: color)
            }
            .buttonStyle(.plain)
            .help(url.absoluteString)
        } else {
            TagContent(name: name, color: color)
        }
    }
}

private struct TagContent: View {
    let name: String
    let color: Color
    
    var body: some View {
        Text(name)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentRow: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                currentX = 0
                currentRow += size.height + spacing
            }
            
            currentX += size.width + spacing
            height = max(height, currentRow + size.height)
        }
        
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            
            view.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
} 