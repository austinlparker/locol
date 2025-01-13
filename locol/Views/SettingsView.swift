import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: CollectorManager
    @State private var availableReleases: [Release] = []
    @State private var isLoadingReleases: Bool = false
    @State private var hasFetchedReleases: Bool = false
    @State private var downloadedReleases: [String: Bool] = UserDefaults.standard.dictionary(forKey: "DownloadedReleases") as? [String: Bool] ?? [:]
    @State private var selectedVersion: String? = nil

    var body: some View {
        GeometryReader { geometry in
            HStack {
                // Left: List of Releases (1/3 of the window width)
                VStack(alignment: .leading) {
                    List {
                        Section(header: Text("Releases")
                            .font(.title2)
                            .padding(.bottom)
                        ) {
                            if isLoadingReleases {
                                ProgressView("Loading Releases...")
                                    .frame(maxWidth: .infinity)
                            } else if availableReleases.isEmpty {
                                Text("No releases available.")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(availableReleases, id: \.tagName) { release in
                                    Section(header: Text(release.tagName).font(.headline)) {
                                        if let assets = release.assets, !assets.isEmpty {
                                            ForEach(assets, id: \.id) { asset in
                                                assetRow(asset: asset)
                                            }
                                        } else {
                                            Text("No assets available.")
                                                .foregroundColor(.secondary)
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                        Button("Refresh Releases") {
                            fetchReleases(forceRefresh: true)
                        }
                        .padding()
                    }
                }
                .frame(width: geometry.size.width / 3) // 1/3 of the window width
                .padding()

                Divider() // Separator between the two sections

                // Right: Download Status or Configuration Dialog
                VStack(alignment: .leading) {
                    if let version = selectedVersion {
                        Text("Configuration for \(version)")
                            .font(.title2)
                            .padding(.bottom)

                        // Command Line Options and Configuration
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Collector Arguments")
                                .font(.headline)

                            TextEditor(text: Binding(
                                get: { manager.commandLineFlags[version] ?? "" },
                                set: { manager.commandLineFlags[version] = $0 }
                            ))
                            .frame(height: 100)
                            .border(Color.gray, width: 1)
                            .cornerRadius(5)

                            Button("Save") {
                                manager.saveCommandLineFlags(for: version)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                        .padding(.horizontal)

                        Spacer()
                        
                        Button("Close") {
                            selectedVersion = nil
                        }
                    } else {
                        // Download Status
                        Text("Download Status")
                            .font(.title2)
                            .padding(.bottom)

                        if manager.downloadProgress > 0 && manager.downloadProgress < 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                ProgressView(value: manager.downloadProgress)
                                    .frame(maxWidth: .infinity)
                                Text(String(format: "%.0f%% Complete", manager.downloadProgress * 100))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(manager.downloadStatus.isEmpty ? "No downloads in progress." : manager.downloadStatus)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
                .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 400) // Adjust the minimum size as needed
        .onAppear {
            if !hasFetchedReleases {
                fetchReleases()
                hasFetchedReleases = true
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func fetchReleases(forceRefresh: Bool = false) {
        isLoadingReleases = true

        manager.getCollectorReleases(repo: "opentelemetry-collector-releases", forceRefresh: forceRefresh) {
            DispatchQueue.main.async {
                self.isLoadingReleases = false
                self.availableReleases = self.manager.availableReleases
            }
        }
    }

    @ViewBuilder
    private func assetRow(asset: ReleaseAsset) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                // Show only the binary name
                if let binaryName = parseBinaryName(from: asset.name) {
                    Text(binaryName)
                        .font(.headline)
                        .lineLimit(1)
                }

                // Metadata: Architecture and Distribution
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

            if let tag = parseVersionTag(from: asset.name) {
                if downloadedReleases[tag] == true {
                    Button("Manage") {
                        selectedVersion = tag
                    }
                } else {
                    Button("Download") {
                        manager.downloadAsset(releaseAsset: asset, versionTag: tag)
                        downloadedReleases[tag] = true
                        UserDefaults.standard.set(downloadedReleases, forKey: "DownloadedReleases")
                    }
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func parseVersionTag(from name: String) -> String? {
        let pattern = #"_([0-9]+\.[0-9]+\.[0-9]+)_"#
        if let match = name.range(of: pattern, options: .regularExpression) {
            let tag = name[match].replacingOccurrences(of: "_", with: "")
            return tag
        }
        return nil
    }

    private func parseBinaryName(from name: String) -> String? {
        // Extract the binary name by taking the part before the first "_"
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
