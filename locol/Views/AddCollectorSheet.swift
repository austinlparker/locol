import SwiftUI

struct AddCollectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var manager: CollectorManager
    @Binding var name: String
    @Binding var selectedRelease: Release?
    @State private var selectedAsset: ReleaseAsset?
    @FocusState private var isNameFieldFocused: Bool
    
    private var idealWidth: CGFloat {
        horizontalSizeClass == .compact ? 300 : 500
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if manager.isDownloading {
                ProgressView {
                    Text(manager.downloadStatus)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                .controlSize(.large)
                .padding()
            } else if manager.isLoadingReleases {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Fetching available versions...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                Form {
                    Section {
                        TextField("Name", text: $name)
                            .focused($isNameFieldFocused)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                        
                        if name.isEmpty {
                            Text("Name is required")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Collector Name")
                            .font(.headline)
                    }
                    
                    if manager.availableReleases.isEmpty {
                        Section {
                            ContentUnavailableView {
                                Label("No Versions Available", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text("Try refreshing the list")
                            } actions: {
                                Button("Refresh") {
                                    manager.getCollectorReleases(repo: "opentelemetry-collector-releases", forceRefresh: true)
                                }
                            }
                        }
                    } else {
                        Section {
                            ReleaseSelectionView(
                                releases: manager.availableReleases,
                                selectedAssetId: selectedAsset?.id,
                                onAssetSelected: { release, asset in
                                    selectedAsset = asset
                                    selectedRelease = release
                                }
                            )
                        } header: {
                            Text("Version")
                                .font(.headline)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
            
            // Footer with buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(manager.isDownloading)
                
                Button("Add") {
                    if let release = selectedRelease, let asset = selectedAsset {
                        manager.addCollector(
                            name: name,
                            version: release.tagName,
                            release: release,
                            asset: asset
                        )
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(name.isEmpty || selectedAsset == nil || manager.isDownloading)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(minWidth: idealWidth, maxWidth: 600)
        .onAppear {
            isNameFieldFocused = true
            if manager.availableReleases.isEmpty {
                manager.getCollectorReleases(repo: "opentelemetry-collector-releases")
            }
        }
        .onChange(of: manager.isDownloading) { oldValue, newValue in
            if !newValue {
                dismiss()
            }
        }
    }
} 