import SwiftUI

struct AttributeFilter: Identifiable, Hashable {
    let id = UUID()
    var key: String
    var value: String
    var isEnabled: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AttributeFilter, rhs: AttributeFilter) -> Bool {
        lhs.id == rhs.id
    }
}

struct AttributeFilterView: View {
    @Binding var filters: [AttributeFilter]
    let availableKeys: [String]
    let onFilterChange: ([AttributeFilter]) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($filters) { $filter in
                HStack {
                    Toggle("", isOn: $filter.isEnabled)
                        .labelsHidden()
                        .onChange(of: filter.isEnabled) { oldValue, newValue in
                            onFilterChange(filters)
                        }
                    
                    Picker("Key", selection: $filter.key) {
                        ForEach(availableKeys, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .frame(width: 150)
                    
                    TextField("Value", text: $filter.value)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onChange(of: filter.value) { oldValue, newValue in
                            onFilterChange(filters)
                        }
                    
                    Button(role: .destructive) {
                        withAnimation {
                            filters.removeAll { $0.id == filter.id }
                            onFilterChange(filters)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button {
                withAnimation {
                    filters.append(AttributeFilter(
                        key: availableKeys.first ?? "",
                        value: "",
                        isEnabled: true
                    ))
                    onFilterChange(filters)
                }
            } label: {
                Label("Add Filter", systemImage: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .disabled(availableKeys.isEmpty)
        }
        .padding()
    }
} 