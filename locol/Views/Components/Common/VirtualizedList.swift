import SwiftUI

struct VirtualizedList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    let spacing: CGFloat
    
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    private let estimatedRowHeight: CGFloat = 44
    private let bufferMultiplier: CGFloat = 2
    
    init(
        data: Data,
        spacing: CGFloat = 0,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
        self.spacing = spacing
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(visibleItems) { item in
                        content(item)
                            .id(item.id)
                    }
                }
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: ContentHeightPreferenceKey.self,
                            value: contentGeometry.size.height
                        )
                    }
                }
            }
            .background {
                GeometryReader { scrollGeometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: scrollGeometry.frame(in: .named("scroll")).minY
                    )
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                contentHeight = height
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                scrollOffset = -offset
            }
            .onAppear {
                viewportHeight = geometry.size.height
            }
        }
    }
    
    private var visibleItems: [Data.Element] {
        guard !data.isEmpty else { return [] }
        
        let totalItems = data.count
        let itemHeight = estimatedRowHeight + spacing
        let visibleItems = Int((viewportHeight / itemHeight) * bufferMultiplier)
        let halfVisibleItems = visibleItems / 2
        
        let offset = scrollOffset
        let centerIndex = Int(offset / itemHeight)
        
        let startIndex = max(0, centerIndex - halfVisibleItems)
        let endIndex = min(totalItems, centerIndex + halfVisibleItems)
        
        return Array(data[data.index(data.startIndex, offsetBy: startIndex)..<data.index(data.startIndex, offsetBy: endIndex)])
    }
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 