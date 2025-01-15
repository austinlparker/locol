import SwiftUI

struct ReleaseAssetRow: View {
    let asset: ReleaseAsset
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var binaryName: String {
        asset.name.components(separatedBy: "_").first ?? ""
    }
    
    private var architecture: String {
        if asset.name.contains("arm64") {
            return "Apple Silicon"
        } else if asset.name.contains("amd64") {
            return "Intel"
        }
        return "Unknown"
    }
    
    private var architectureIcon: String {
        if asset.name.contains("arm64") {
            return "cpu"
        } else if asset.name.contains("amd64") {
            return "desktopcomputer"
        }
        return "questionmark"
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(binaryName)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label(architecture, systemImage: architectureIcon)
                        Label("macOS", systemImage: "applelogo")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

struct ReleaseSection: View {
    let release: Release
    let selectedAssetId: Int?
    let onAssetSelected: (ReleaseAsset) -> Void
    
    private var compatibleAssets: [ReleaseAsset] {
        release.assets?.filter { $0.name.contains("darwin") } ?? []
    }
    
    var body: some View {
        DisclosureGroup {
            if !compatibleAssets.isEmpty {
                ForEach(compatibleAssets, id: \.id) { asset in
                    ReleaseAssetRow(
                        asset: asset,
                        isSelected: selectedAssetId == asset.id,
                        onSelect: { onAssetSelected(asset) }
                    )
                }
            } else {
                Text("No compatible assets available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        } label: {
            HStack {
                Text(release.tagName)
                    .font(.headline)
                if release.tagName.hasPrefix("v") {
                    Text("Latest")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ReleaseSelectionView: View {
    let releases: [Release]
    let selectedAssetId: Int?
    let onAssetSelected: (Release, ReleaseAsset) -> Void
    
    var body: some View {
        List(selection: .constant(selectedAssetId)) {
            ForEach(releases, id: \.tagName) { release in
                DisclosureGroup {
                    if let assets = release.assets {
                        ForEach(assets.filter { $0.name.contains("darwin") }, id: \.id) { asset in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(asset.name)
                                        .font(.system(.body, design: .monospaced))
                                    Text("\(ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedAssetId == asset.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onAssetSelected(release, asset)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(release.tagName)
                            .font(.headline)
                        if release.tagName == releases.first?.tagName {
                            Text("Latest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
} 