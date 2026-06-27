import SwiftUI

struct AIProviderFormView: View {
    let provider: AIProviderConfig?
    let onSave: (AIProviderConfig?) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var displayName: String = ""
    @State private var kind: AIProviderKind = .openAICompatibleChat
    @State private var baseURL: String = ""
    @State private var modelID: String = ""
    @State private var apiKey: String = ""
    @State private var supportsStreaming: Bool = false
    @State private var timeoutSeconds: Double = 60
    @State private var maxOutputTokens: Int = 2048
    @State private var temperature: Double = 0.2
    @State private var extraParametersJSON: String = ""
    @State private var isDefault: Bool = false

    @State private var testing: Bool = false
    @State private var testResult: String?
    @State private var testLatencyMs: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("基本") {
                        VStack(alignment: .leading, spacing: 10) {
                            labeledTextField("显示名称", text: $displayName)
                            Picker("API 类型", selection: $kind) {
                                ForEach(AIProviderKind.allCases, id: \.self) { k in
                                    Text(k.displayName).tag(k)
                                }
                            }
                            labeledTextField("Base URL", text: $baseURL)
                            labeledTextField("Model ID", text: $modelID)
                            Toggle("设为默认", isOn: $isDefault)
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("API Key") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                MacTextField(placeholder: "API Key", text: $apiKey)
                                    .frame(height: 26)
                                Button("粘贴") {
                                    if let pasted = NSPasteboard.general.string(forType: .string) {
                                        apiKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                }
                            }
                            Text("API Key 可直接粘贴；保存后写入本地 Provider 配置。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("参数") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("启用流式输出", isOn: $supportsStreaming)
                            HStack {
                                Text("Timeout")
                                Spacer()
                                Stepper(value: $timeoutSeconds, in: 10...300, step: 10) {
                                    Text("\(Int(timeoutSeconds)) 秒")
                                }
                            }
                            HStack {
                                Text("Temperature")
                                Slider(value: $temperature, in: 0...1, step: 0.1)
                                Text(String(format: "%.2f", temperature)).monospacedDigit()
                            }
                            HStack {
                                Text("Max Tokens")
                                Spacer()
                                Stepper(value: $maxOutputTokens, in: 256...16384, step: 256) {
                                    Text("\(maxOutputTokens)")
                                }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("额外参数 JSON（可选）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $extraParametersJSON)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(minHeight: 72)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("连接测试") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("测试连接") { test() }
                                    .disabled(testing)
                                if testing {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            if let result = testResult {
                                Text(result)
                                    .font(.callout)
                                    .foregroundStyle(result.hasPrefix("成功") ? .green : .red)
                                if let latency = testLatencyMs {
                                    Text("延迟: \(latency) ms").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消") { onSave(nil) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .disabled(displayName.isEmpty || baseURL.isEmpty || modelID.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { populate() }
    }

    private func populate() {
        if let provider {
            displayName = provider.displayName
            kind = provider.kind
            baseURL = provider.baseURLString
            modelID = provider.modelID
            supportsStreaming = provider.supportsStreaming
            timeoutSeconds = provider.timeoutSeconds
            maxOutputTokens = provider.maxOutputTokens
            temperature = provider.temperature
            extraParametersJSON = provider.extraParametersJSON ?? ""
            isDefault = provider.isDefault
            apiKey = provider.apiKey
        }
    }

    private func save() {
        let id = provider?.id ?? UUID().uuidString
        if provider == nil {
            let new = AIProviderConfig(
                id: id,
                displayName: displayName,
                kindRawValue: kind.rawValue,
                baseURLString: baseURL,
                modelID: modelID,
                apiKey: apiKey,
                isDefault: isDefault,
                supportsStreaming: supportsStreaming,
                timeoutSeconds: timeoutSeconds,
                maxOutputTokens: maxOutputTokens,
                temperature: temperature,
                extraParametersJSON: extraParametersJSON.isEmpty ? nil : extraParametersJSON
            )
            appState.persistence.container.mainContext.insert(new)
            if isDefault { clearOtherDefaults(except: id) }
            appState.persistence.save()
        } else {
            provider?.displayName = displayName
            provider?.kindRawValue = kind.rawValue
            provider?.baseURLString = baseURL
            provider?.modelID = modelID
            provider?.apiKey = apiKey
            provider?.supportsStreaming = supportsStreaming
            provider?.timeoutSeconds = timeoutSeconds
            provider?.maxOutputTokens = maxOutputTokens
            provider?.temperature = temperature
            provider?.extraParametersJSON = extraParametersJSON.isEmpty ? nil : extraParametersJSON
            provider?.isDefault = isDefault
            provider?.updatedAt = .now
            if isDefault { clearOtherDefaults(except: id) }
            appState.persistence.save()
        }
        onSave(provider ?? AIProviderConfig(
            id: id,
            displayName: displayName,
            kindRawValue: kind.rawValue,
            baseURLString: baseURL,
            modelID: modelID,
            apiKey: apiKey,
            isDefault: isDefault
        ))
    }

    @ViewBuilder
    private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            MacTextField(placeholder: title, text: text)
                .frame(height: 26)
        }
    }

    private func clearOtherDefaults(except id: String) {
        for p in appState.persistence.fetchProviders() where p.id != id {
            p.isDefault = false
        }
    }

    private func test() {
        testing = true
        testResult = nil
        testLatencyMs = nil
        Task {
            let config = AIProviderConfig(
                displayName: displayName,
                kindRawValue: kind.rawValue,
                baseURLString: baseURL,
                modelID: modelID,
                apiKey: apiKey,
                isDefault: false,
                supportsStreaming: supportsStreaming,
                maxOutputTokens: min(maxOutputTokens, 64),
                temperature: temperature,
                extraParametersJSON: extraParametersJSON.isEmpty ? nil : extraParametersJSON
            )
            let runtimeConfig = ProviderRuntimeConfig(config)
            let client = AIProviderClientFactory().makeClient(for: runtimeConfig.kind)
            let start = Date()
            do {
                let reply = try await client.generateText(
                    messages: [.user("Reply with the single word: OK")],
                    config: runtimeConfig,
                    apiKey: apiKey
                )
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                testLatencyMs = ms
                testResult = "成功: \(reply.prefix(80))"
            } catch {
                testResult = "失败: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
