import SwiftUI

// Traces Configuration Views
struct TracesConfigView: View {
    @Binding var config: TracesConfig
    
    var body: some View {
        Section("Traces Configuration") {
            Picker("Mode", selection: $config.mode) {
                ForEach(TracesConfig.TraceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized)
                        .tag(mode)
                }
            }
            
            switch config.mode {
            case .single:
                SingleTraceConfigView(config: $config.singleConfig)
            case .multi:
                MultiTraceConfigView(config: $config.multiConfig)
            }
        }
    }
}

struct SingleTraceConfigView: View {
    @Binding var config: SingleTraceConfig
    
    var body: some View {
        Toggle("Marshal Trace Context", isOn: $config.marshal)
        
        Picker("Scenario", selection: $config.scenario) {
            ForEach(SingleTraceConfig.SingleTraceScenario.allCases, id: \.self) { scenario in
                Text(scenario.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .tag(scenario)
            }
        }
    }
}

struct MultiTraceConfigView: View {
    @Binding var config: MultiTraceConfig
    @State private var selectedScenarios: Set<MultiTraceConfig.MultiTraceScenario> = []
    
    var body: some View {
        ForEach(MultiTraceConfig.MultiTraceScenario.allCases, id: \.self) { scenario in
            Toggle(scenario.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                   isOn: Binding(
                    get: { config.scenarios.contains(scenario) },
                    set: { isSelected in
                        if isSelected {
                            config.scenarios.append(scenario)
                        } else {
                            config.scenarios.removeAll { $0 == scenario }
                        }
                    }
                   ))
        }
        
        HStack {
            Text("Number of Traces")
            Spacer()
            TextField("Traces", value: $config.numberTraces, format: .number)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
        
        HStack {
            Text("Workers")
            Spacer()
            TextField("Workers", value: $config.workers, format: .number)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }
}

// Metrics Configuration Views
struct MetricsConfigView: View {
    @Binding var config: MetricsConfig
    
    var body: some View {
        Section("Metrics Configuration") {
            Picker("Type", selection: $config.type) {
                ForEach(MetricsConfig.MetricType.allCases, id: \.self) { type in
                    Text(type.rawValue.replacingOccurrences(of: "-", with: " ").capitalized)
                        .tag(type)
                }
            }
            
            switch config.type {
            case .exponentialHistogram:
                ExponentialHistogramConfigView(config: $config.exponentialHistogramConfig)
            case .gauge:
                GaugeConfigView(config: $config.gaugeConfig)
            case .histogram:
                HistogramConfigView(config: $config.histogramConfig)
            case .sum:
                SumConfigView(config: $config.sumConfig)
            }
        }
    }
}

struct MetricBaseConfigView<Content: View>: View {
    let title: String
    @Binding var temporality: Temporality
    @Binding var unit: String
    @Binding var attributes: [String: String]
    @State private var newAttributeKey = ""
    @State private var newAttributeValue = ""
    let content: Content
    
    init(
        title: String,
        temporality: Binding<Temporality>,
        unit: Binding<String>,
        attributes: Binding<[String: String]>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._temporality = temporality
        self._unit = unit
        self._attributes = attributes
        self.content = content()
    }
    
    var body: some View {
        Group {
            Text(title)
                .font(.headline)
            
            Picker("Temporality", selection: $temporality) {
                ForEach(Temporality.allCases, id: \.self) { temp in
                    Text(temp.rawValue.capitalized)
                        .tag(temp)
                }
            }
            
            TextField("Unit", text: $unit)
            
            Section("Attributes") {
                ForEach(Array(attributes.keys), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Text(attributes[key] ?? "")
                        Button(role: .destructive) {
                            attributes.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                
                HStack {
                    TextField("Key", text: $newAttributeKey)
                    TextField("Value", text: $newAttributeValue)
                    Button("Add") {
                        if !newAttributeKey.isEmpty {
                            attributes[newAttributeKey] = newAttributeValue
                            newAttributeKey = ""
                            newAttributeValue = ""
                        }
                    }
                    .disabled(newAttributeKey.isEmpty)
                }
            }
            
            content
        }
    }
}

struct ExponentialHistogramConfigView: View {
    @Binding var config: ExponentialHistogramConfig
    
    var body: some View {
        MetricBaseConfigView(
            title: "Exponential Histogram",
            temporality: $config.temporality,
            unit: $config.unit,
            attributes: $config.attributes
        ) {
            HStack {
                Text("Scale")
                Spacer()
                TextField("Scale", value: $config.scale, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Max Size")
                Spacer()
                TextField("Max Size", value: $config.maxSize, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
            
            Toggle("Record Min/Max", isOn: $config.recordMinMax)
            
            HStack {
                Text("Zero Threshold")
                Spacer()
                TextField("Zero Threshold", value: $config.zeroThreshold, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

struct GaugeConfigView: View {
    @Binding var config: GaugeConfig
    
    var body: some View {
        MetricBaseConfigView(
            title: "Gauge",
            temporality: $config.temporality,
            unit: $config.unit,
            attributes: $config.attributes
        ) {
            HStack {
                Text("Minimum Value")
                Spacer()
                TextField("Min", value: $config.min, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Maximum Value")
                Spacer()
                TextField("Max", value: $config.max, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

struct HistogramConfigView: View {
    @Binding var config: HistogramConfig
    @State private var newBound: Int = 0
    
    var body: some View {
        MetricBaseConfigView(
            title: "Histogram",
            temporality: $config.temporality,
            unit: $config.unit,
            attributes: $config.attributes
        ) {
            Toggle("Record Min/Max", isOn: $config.recordMinMax)
            
            Text("Bounds")
                .font(.headline)
            
            ForEach(config.bounds, id: \.self) { bound in
                HStack {
                    Text("\(bound)")
                    Spacer()
                    Button {
                        if let index = config.bounds.firstIndex(of: bound) {
                            config.bounds.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            
            HStack {
                TextField("New Bound", value: $newBound, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                Button("Add") {
                    config.bounds.append(newBound)
                    config.bounds.sort()
                }
            }
        }
    }
}

struct SumConfigView: View {
    @Binding var config: SumConfig
    
    var body: some View {
        MetricBaseConfigView(
            title: "Sum",
            temporality: $config.temporality,
            unit: $config.unit,
            attributes: $config.attributes
        ) {
            Toggle("Monotonic", isOn: $config.monotonic)
        }
    }
}

// Logs Configuration Views
struct LogsConfigView: View {
    @Binding var config: LogsConfig
    
    var body: some View {
        Section("Logs Configuration") {
            Picker("Mode", selection: $config.mode) {
                ForEach(LogsConfig.LogMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized)
                        .tag(mode)
                }
            }
            
            if case .multi = config.mode {
                MultiLogConfigView(config: $config.multiConfig)
            }
        }
    }
}

struct MultiLogConfigView: View {
    @Binding var config: MultiLogConfig
    
    var body: some View {
        HStack {
            Text("Number of Logs")
            Spacer()
            TextField("Logs", value: $config.number, format: .number)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
        
        HStack {
            Text("Workers")
            Spacer()
            TextField("Workers", value: $config.workers, format: .number)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
        
        HStack {
            Text("Duration (seconds)")
            Spacer()
            TextField("Duration", value: $config.duration, format: .number)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }
} 