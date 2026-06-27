import SwiftUI

struct AIProviderSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var providers: [AIProviderConfig] = []
    @State private var editingProvider: AIProviderConfig?
    @State private var isCreatingProvider: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCreatingProvider || editingProvider != nil {
                editorHeader
                Divider()
                AIProviderFormView(provider: editingProvider) { _ in
                    isCreatingProvider = false
                    editingProvider = nil
                    reload()
                }
            } else {
                HStack {
                    Text("AI Provider 列表").font(.headline)
                    Spacer()
                    Button("新增 Provider") { isCreatingProvider = true }
                    Button("从模板加载内置 Provider") {
                        appState.ensureDefaultProviderTemplates()
                        reload()
                    }
                }
                .padding(.bottom, 8)

                Divider()

                if providers.isEmpty {
                    Text("尚未配置 Provider。点击「从模板加载内置 Provider」可快速开始。")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(providers) { provider in
                            ProviderRow(
                                provider: provider,
                                onSetDefault: { setDefault(provider) },
                                onEdit: { editingProvider = provider },
                                onDelete: { delete(provider) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear { reload() }
    }

    private var editorHeader: some View {
        HStack {
            Button {
                isCreatingProvider = false
                editingProvider = nil
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            Text(isCreatingProvider ? "新增 Provider" : "编辑 Provider")
                .font(.headline)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func reload() {
        providers = appState.persistence.fetchProviders()
    }

    private func setDefault(_ provider: AIProviderConfig) {
        for p in providers { p.isDefault = (p.id == provider.id) }
        appState.persistence.save()
        reload()
    }

    private func delete(_ provider: AIProviderConfig) {
        appState.persistence.delete(provider)
        appState.persistence.save()
        reload()
    }

}

private struct ProviderRow: View {
    let provider: AIProviderConfig
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(provider.displayName).font(.headline)
                    if provider.isDefault {
                        Text("默认").font(.caption).padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Text(provider.kind.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(provider.baseURLString).font(.caption).foregroundStyle(.secondary)
                Text("Model: \(provider.modelID)").font(.caption).foregroundStyle(.tertiary)
                Text("Temperature \(String(format: "%.2f", provider.temperature)) · Max \(provider.maxOutputTokens) tokens\(provider.supportsStreaming ? " · 流式" : "")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Button("设为默认") { onSetDefault() }.disabled(provider.isDefault)
                Button("编辑") { onEdit() }
                Button("删除", role: .destructive) { onDelete() }
            }
        }
        .padding(.vertical, 4)
    }
}
