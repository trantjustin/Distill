import SwiftUI

struct SettingsView: View {
    @AppStorage("ai_provider")        private var selectedProvider: String = AIProvider.openAI.rawValue
    @AppStorage("openai_api_key")     private var openAIKey: String = ""
    @AppStorage("claude_api_key")     private var claudeKey: String = ""
    @AppStorage("gemini_api_key")     private var geminiKey: String = ""
    @AppStorage("perplexity_api_key") private var perplexityKey: String = ""

    private func hasKey(for provider: AIProvider) -> Bool {
        switch provider {
        case .openAI:     return !openAIKey.isEmpty
        case .claude:     return !claudeKey.isEmpty
        case .gemini:     return !geminiKey.isEmpty
        case .perplexity: return !perplexityKey.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if unlockedCount == 0 {
                        Text("Enter an API key below to get started.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if unlockedCount == 1 {
                        let active = AIProvider.allCases.first(where: { hasKey(for: $0) })!
                        LabeledContent("Active Provider", value: active.rawValue)
                    } else {
                        Picker("Active Provider", selection: $selectedProvider) {
                            ForEach(AIProvider.allCases.filter { hasKey(for: $0) }) { provider in
                                Text(provider.rawValue).tag(provider.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text("Only providers with a configured API key are available.")
                }
                .onAppear { fixSelectionIfNeeded() }
                .onChange(of: openAIKey)     { _, _ in fixSelectionIfNeeded() }
                .onChange(of: claudeKey)     { _, _ in fixSelectionIfNeeded() }
                .onChange(of: geminiKey)     { _, _ in fixSelectionIfNeeded() }
                .onChange(of: perplexityKey) { _, _ in fixSelectionIfNeeded() }

                Section {
                    ForEach(AIProvider.allCases) { provider in
                        APIKeyRow(provider: provider)
                    }
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("Keys are stored securely on-device and never shared. Only the selected provider's key is used. You are responsible for all usage and costs incurred on your API account.")
                }

                Section("Widget") {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Home Screen Widget")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Long-press your home screen → + → Distill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Customise the Widget")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Long-press the widget → Edit Widget to change colour theme, refresh rate, and attribution")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("AI", value: selectedProvider)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var unlockedCount: Int {
        AIProvider.allCases.filter { hasKey(for: $0) }.count
    }

    private func fixSelectionIfNeeded() {
        let current = AIProvider(rawValue: selectedProvider)
        if let current, hasKey(for: current) { return }
        if let first = AIProvider.allCases.first(where: { hasKey(for: $0) }) {
            selectedProvider = first.rawValue
        }
    }

}

enum KeyValidationState {
    case empty, valid, invalid
}

struct APIKeyRow: View {
    let provider: AIProvider
    @State private var apiKey: String = ""
    @State private var showingKey = false
    @State private var validationState: KeyValidationState = .empty
    private var storageKey: String { provider.apiKeyStorageKey }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(provider.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                validationBadge
            }

            HStack(spacing: 8) {
                Group {
                    if showingKey {
                        TextField(provider.keyPlaceholder, text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: apiKey) { _, v in onKeyChanged(v) }
                    } else {
                        SecureField(provider.keyPlaceholder, text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: apiKey) { _, v in onKeyChanged(v) }
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(fieldBorderColor, lineWidth: validationState == .invalid ? 1.5 : 0)
                )

                Button {
                    showingKey.toggle()
                } label: {
                    Image(systemName: showingKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }

            if validationState == .invalid {
                Label("Invalid API key", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: storageKey) ?? ""
            if !apiKey.isEmpty { validationState = .valid }
        }
    }

    @ViewBuilder
    private var validationBadge: some View {
        switch validationState {
        case .empty:   EmptyView()
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.caption)
        case .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red).font(.caption)
        }
    }

    private var fieldBackground: Color {
        switch validationState {
        case .invalid: return .red.opacity(0.06)
        default:       return .secondary.opacity(0.1)
        }
    }

    private var fieldBorderColor: Color {
        validationState == .invalid ? .red.opacity(0.4) : .clear
    }

    private func onKeyChanged(_ value: String) {
        save(value)
        guard !value.isEmpty else { validationState = .empty; return }
        let isValid = AIService.shared.validateKey(for: provider, apiKey: value)
        validationState = isValid ? .valid : .invalid
    }

    private func save(_ value: String) {
        UserDefaults.standard.set(value, forKey: storageKey)
    }
}
