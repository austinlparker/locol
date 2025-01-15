import SwiftUI

struct AddCollectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: CollectorManager
    @Binding var name: String
    @Binding var selectedRelease: Release?
    @State private var selectedAsset: ReleaseAsset?
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if manager.isDownloading {
                VStack(spacing: 8) {
                    Text(manager.downloadStatus)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ProgressView(value: manager.downloadProgress)
                        .progressViewStyle(.linear)
                        .controlSize(.large)
                }
                .padding()
                .frame(width: 300)
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
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .frame(width: 500)
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
        .frame(width: manager.isDownloading ? 300 : 500)
        .fixedSize()
        .onAppear {
            isNameFieldFocused = true
        }
        .onChange(of: manager.isDownloading) { oldValue, newValue in
            if !newValue {
                dismiss()
            }
        }
    }
} 