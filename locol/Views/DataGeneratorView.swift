import SwiftUI

/// Placeholder view for the data generator feature
/// TODO: Reimplement data generator functionality
struct DataGeneratorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Data Generator")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This feature is being reimplemented")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Coming Soon") {
                // TODO: Implement new data generator functionality
            }
            .disabled(true)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

#Preview {
    DataGeneratorView()
}