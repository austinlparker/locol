import SwiftUI

struct AddCollectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let appState: AppState
    @Binding var name: String
    @Binding var selectedRelease: Release?
    @State private var selectedAsset: ReleaseAsset?
    @FocusState private var isNameFieldFocused: Bool
    
    private var idealWidth: CGFloat {
        horizontalSizeClass == .compact ? 300 : 500
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if appState.isDownloading {
                ProgressView {
                    Text(appState.downloadStatus)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                .controlSize(.large)
                .padding()
            } else if appState.isLoadingReleases {
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
                    
                    if appState.availableReleases.isEmpty {
                        Section {
                            ContentUnavailableView {
                                Label("No Versions Available", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text("Try refreshing the list")
                            } actions: {
                                Button("Refresh") {
                                    appState.getCollectorReleases(repo: "opentelemetry-collector-releases", forceRefresh: true)
                                }
                            }
                            .padding()
                        }
                    } else {
                        Section {
                            ReleaseSelectionView(
                                releases: appState.availableReleases,
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
                .frame(maxHeight: 500)
            }
            
            // Footer with buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(appState.isDownloading)
                
                Button("Add") {
                    if let release = selectedRelease, let asset = selectedAsset {
                        let collector = CollectorInstance(
                            name: name,
                            version: release.tagName,
                            binaryPath: "", // This will be set by AppState
                            configPath: ""  // This will be set by AppState
                        )
                        appState.addCollector(collector)
                        dismiss()
                        selectedAsset = nil
                        selectedRelease = nil
                        name = ""
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(name.isEmpty || selectedAsset == nil || appState.isDownloading)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: idealWidth)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            isNameFieldFocused = true
            if appState.availableReleases.isEmpty {
                appState.getCollectorReleases(repo: "opentelemetry-collector-releases")
            }
        }
        .onChange(of: appState.isDownloading) { oldValue, newValue in
            if !newValue {
                dismiss()
            }
        }
    }
} 
