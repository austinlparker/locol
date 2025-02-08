import SwiftUI

// MARK: - Table Configurations

private enum Tab: String, CaseIterable {
    case resources, query
    
    var systemImage: String {
        switch self {
        case .resources: return "square.3.layers.3d"
        case .query: return "terminal"
        }
    }
    
    var title: String {
        rawValue.capitalized
    }
}

struct DataExplorerView: View {
    let dataExplorer: DataExplorerProtocol
    @State private var selectedTab = Tab.resources
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Resources tab
            ResourceExplorerView(dataExplorer: dataExplorer)
                .tabItem {
                    Label("Resources", systemImage: Tab.resources.systemImage)
                }
                .tag(Tab.resources)
            
            // Query tab
            QueryView(dataExplorer: dataExplorer)
                .tabItem {
                    Label("Query", systemImage: Tab.query.systemImage)
                }
                .tag(Tab.query)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if dataExplorer.isRunning {
                    Button {
                        Task {
                            await dataExplorer.stop()
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        Task {
                            try? await dataExplorer.start()
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            ToolbarItem(placement: .status) {
                if dataExplorer.isRunning {
                    Label("Running on port \(dataExplorer.serverPort)", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Stopped", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .status) {
                Text("Port: \(dataExplorer.serverPort)")
                    .foregroundStyle(.secondary)
            }

            if let error = dataExplorer.error {
                ToolbarItem(placement: .status) {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}