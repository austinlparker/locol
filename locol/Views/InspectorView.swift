import SwiftUI
import GRDBQuery

struct InspectorView: View {
    let item: SidebarItem?
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch item {
                case .collector(let id):
                    CollectorInspector(collectorId: id)

                case .otlpReceiver:
                    OTLPReceiverInspector()

                case .telemetryViewer:
                    TelemetryInspector()

                case .dataGenerator:
                    DataGeneratorInspector()

                case nil:
                    EmptyInspector()
                }
            }
            .padding()
        }
        .navigationTitle("Inspector")
    }
}

// MARK: - Collector Inspector

struct CollectorInspector: View {
    let collectorId: UUID
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Component Library
            ComponentLibraryView()
        }
    }

}

// MARK: - Component Library View

struct ComponentLibraryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.databaseContext) private var databaseContext
    @Query(ComponentsRequest()) private var allComponents: [CollectorComponent]
    @State private var searchText = ""
    @State private var selectedType: ComponentType? = nil

    private var filteredComponents: [CollectorComponent] {
        let typeFiltered = selectedType == nil ? allComponents : allComponents.filter { $0.type == selectedType }
        return searchText.isEmpty ? typeFiltered : typeFiltered.filter { component in
            component.name.localizedCaseInsensitiveContains(searchText) ||
            component.description?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var componentsByType: [(ComponentType, [CollectorComponent])] {
        let types: [ComponentType] = [.receiver, .processor, .exporter, .extension, .connector]
        return types.compactMap { type in
            let components = filteredComponents.filter { $0.type == type }
            return components.isEmpty ? nil : (type, components)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            InspectorSectionHeader("COMPONENTS")

            // Search bar
            TextField("Search components...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )

                    ForEach([ComponentType.receiver, .processor, .exporter, .extension, .connector], id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            // Component list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if filteredComponents.isEmpty {
                        VStack {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No components found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(componentsByType, id: \.0) { type, components in
                            VStack(alignment: .leading, spacing: 4) {
                                // Type header
                                HStack {
                                    Image(systemName: iconForComponentType(type))
                                        .font(.caption2)
                                        .foregroundColor(type.color)
                                    Text(type.displayName)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(type.color)
                                    Spacer()
                                    Text("\\(components.count)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                // Components of this type
                                ForEach(components) { component in
                                    ComponentRow(component: component)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func iconForComponentType(_ type: ComponentType) -> String {
        switch type {
        case .receiver:
            return "antenna.radiowaves.left.and.right"
        case .processor:
            return "gearshape.2"
        case .exporter:
            return "arrow.up.right"
        case .extension:
            return "puzzlepiece.extension"
        case .connector:
            return "cable.connector"
        }
    }
}

struct ComponentRow: View {
    let component: CollectorComponent
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let description = component.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color(.controlAccentColor).opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? Color(.controlAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .draggable("component-definition:\(component.id)") {
            // Drag preview
            HStack {
                Image(systemName: iconForComponentType(component.type))
                    .foregroundColor(component.type.color)
                Text(component.name)
                    .font(.caption)
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    private func iconForComponentType(_ type: ComponentType) -> String {
        switch type {
        case .receiver:
            return "antenna.radiowaves.left.and.right"
        case .processor:
            return "gearshape.2"
        case .exporter:
            return "arrow.up.right"
        case .extension:
            return "puzzlepiece.extension"
        case .connector:
            return "cable.connector"
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color(.controlAccentColor) : Color(.controlBackgroundColor))
        )
        .foregroundColor(isSelected ? .white : .primary)
    }
}

// MARK: - Other Inspectors (Simplified)

struct OTLPReceiverInspector: View {
    var body: some View {
        InspectorSection("OTLP RECEIVER") {
            Text("OTLP receiver configuration")
                .foregroundColor(.secondary)
        }
    }
}

struct TelemetryInspector: View {
    var body: some View {
        InspectorSection("TELEMETRY VIEWER") {
            Text("Telemetry viewer configuration")
                .foregroundColor(.secondary)
        }
    }
}

struct DataGeneratorInspector: View {
    var body: some View {
        InspectorSection("DATA GENERATOR") {
            Text("Data generator configuration")
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyInspector: View {
    var body: some View {
        VStack {
            Image(systemName: "info.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Select an item to inspect")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Views

struct InspectorSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        Section {
            content()
        } header: {
            InspectorSectionHeader(title)
        }
    }
}

struct InspectorSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

struct InspectorRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    InspectorView(item: nil)
        .environment(AppContainer())
}
