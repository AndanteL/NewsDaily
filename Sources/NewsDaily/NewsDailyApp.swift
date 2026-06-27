import SwiftUI
import SwiftData

@main
struct NewsDailyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("NewsDaily") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .modelContainer(appState.persistence.container)
                .frame(minWidth: 1100, minHeight: 680)
                .task {
                    await appState.bootstrap()
                }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新所有来源") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("翻译当前文章") {
                    if let id = appState.selectedArticleID,
                       let article = appState.persistence.fetchArticle(id: id) {
                        Task { await appState.requestTranslation(for: article) }
                    }
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("搜索") {
                    NotificationCenter.default.post(name: .focusSearchField, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                SettingsLink {
                    Text("设置")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .modelContainer(appState.persistence.container)
        }

        MenuBarExtra {
            MenuBarMenuContent(appState: appState)
        } label: {
            Image(systemName: "newspaper")
        }
        .menuBarExtraStyle(.window)
    }
}

extension Notification.Name {
    static let focusSearchField = Notification.Name("focusSearchField")
    static let openSettings = Notification.Name("openSettings")
}

private struct MenuBarMenuContent: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NewsDaily")
                .font(.headline)
            Text(appState.lastError ?? "已就绪")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("刷新") { Task { await appState.refreshAll() } }
            Button("打开主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "NewsDaily" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}

private struct SettingsView: View {
    var body: some View {
        TabView {
            AIProviderSettingsView()
                .tabItem { Label("AI Provider", systemImage: "cpu") }
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gear") }
        }
        .frame(width: 640, height: 520)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("刷新") {
                Toggle("打开 App 时自动刷新", isOn: $settings.autoRefreshOnLaunch)
                Stepper(value: $settings.refreshIntervalMinutes, in: 5...360, step: 5) {
                    Text("自动刷新间隔: \(settings.refreshIntervalMinutes) 分钟")
                }
                Toggle("新文章通知", isOn: $settings.enableNotifications)
            }
            Section("翻译") {
                Picker("目标语言", selection: $settings.targetLanguage) {
                    Text("简体中文").tag("zh-Hans")
                    Text("繁體中文").tag("zh-Hant")
                    Text("English").tag("en")
                }
                Toggle("阅读器默认显示翻译", isOn: $settings.showReaderTranslationByDefault)
                HStack {
                    Text("Temperature")
                    Slider(value: $settings.translationTemperature, in: 0...1, step: 0.1)
                    Text(String(format: "%.1f", settings.translationTemperature)).monospacedDigit()
                }
                HStack {
                    Text("Max Tokens")
                    Stepper(value: $settings.maxOutputTokens, in: 256...8192, step: 256) {
                        Text("\(settings.maxOutputTokens)")
                    }
                }
            }
            Section("iCloud") {
                Toggle("启用 iCloud 同步（实验）", isOn: $settings.iCloudSyncEnabled)
            }
            Section("来源管理") {
                SourcesSettingsView()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct SourcesSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var sources: [NewsSource] = []

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(sources) { source in
                HStack {
                    Toggle(isOn: Binding(
                        get: { source.isEnabled },
                        set: { newValue in
                            source.isEnabled = newValue
                            appState.persistence.save()
                            load()
                        }
                    )) {
                        Text(source.name)
                    }
                    Spacer()
                    if source.isEnabled {
                        Button("立即刷新") {
                            Task { await appState.refresh(sourceID: source.id); load() }
                        }
                    }
                }
            }
            Button("重新加载内置来源") {
                appState.ensureBuiltinSourcesLoaded()
                load()
            }
        }
        .onAppear { load() }
    }

    private func load() {
        sources = appState.persistence.fetchSources()
    }
}
