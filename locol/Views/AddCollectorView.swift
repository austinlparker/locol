import SwiftUI

struct AssetRowView: View {
    let asset: ReleaseAsset
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                if let binaryName = parseBinaryName(from: asset.name) {
                    Text(binaryName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                HStack(spacing: 10) {
                    if let architecture = parseArchitecture(from: asset.name) {
                        Label(architecture, systemImage: architectureIcon(for: architecture))
                    }
                    if let distribution = parseDistribution(from: asset.name) {
                        Label(distribution, systemImage: distributionIcon(for: distribution))
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 5)
    }
    
    private func parseBinaryName(from name: String) -> String? {
        return name.components(separatedBy: "_").first
    }
    
    private func parseArchitecture(from name: String) -> String? {
        if name.contains("arm64") {
            return "ARM64"
        } else if name.contains("amd64") {
            return "AMD64"
        }
        return nil
    }
    
    private func parseDistribution(from name: String) -> String? {
        if name.contains("darwin") {
            return "macOS"
        } else if name.contains("linux") {
            return "Linux"
        }
        return nil
    }
    
    private func architectureIcon(for architecture: String) -> String {
        switch architecture {
        case "ARM64": return "cpu"
        case "AMD64": return "desktopcomputer"
        default: return "questionmark"
        }
    }
    
    private func distributionIcon(for distribution: String) -> String {
        switch distribution {
        case "macOS": return "applelogo"
        case "Linux": return "terminal"
        default: return "questionmark"
        }
    }
}

struct ReleaseListView: View {
    let releases: [Release]
    let selectedAssetId: Int?
    let onAssetSelected: (Release, ReleaseAsset) -> Void
    
    var body: some View {
        List {
            ForEach(releases, id: \.tagName) { release in
                Section {
                    if let assets = release.assets?.filter({ $0.name.contains("darwin") }) {
                        ForEach(assets, id: \.id) { asset in
                            AssetRowView(asset: asset, isSelected: selectedAssetId == asset.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onAssetSelected(release, asset)
                                }
                                .background(selectedAssetId == asset.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                    } else {
                        Text("No compatible assets available.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                } header: {
                    Text(release.tagName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        }
        .listStyle(InsetListStyle())
    }
}

struct AddCollectorView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager: CollectorManager
    @Binding var name: String
    @Binding var selectedRelease: Release?
    @State private var selectedAsset: ReleaseAsset?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 8)
                    
                    if manager.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView(value: manager.downloadProgress)
                            Text(manager.downloadStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    ReleaseListView(
                        releases: manager.availableReleases,
                        selectedAssetId: selectedAsset?.id,
                        onAssetSelected: { release, asset in
                            selectedAsset = asset
                            selectedRelease = release
                        }
                    )
                    .disabled(manager.isDownloading)
                } header: {
                    Text("New Collector")
                        .font(.headline)
                        .textCase(nil)
                }
            }
            .navigationTitle("Add Collector")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(manager.isDownloading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let release = selectedRelease, let asset = selectedAsset {
                            manager.addCollector(
                                name: name,
                                version: release.tagName,
                                release: release,
                                asset: asset
                            )
                            isPresented = false
                            selectedAsset = nil
                            selectedRelease = nil
                            name = ""
                        }
                    }
                    .disabled(name.isEmpty || selectedAsset == nil || manager.isDownloading)
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 600, maxWidth: .infinity, 
               minHeight: 300, idealHeight: 500, maxHeight: .infinity)
    }
} 