import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let defaults = UserDefaults.standard

    @AppStorage("targetLanguage") var targetLanguage: String = "zh-Hans"
    @AppStorage("defaultSidebarSelection") var defaultSidebarSelection: String = "today"
    @AppStorage("autoRefreshOnLaunch") var autoRefreshOnLaunch: Bool = true
    @AppStorage("refreshIntervalMinutes") var refreshIntervalMinutes: Int = 60
    @AppStorage("showReaderTranslationByDefault") var showReaderTranslationByDefault: Bool = false
    @AppStorage("enableNotifications") var enableNotifications: Bool = true
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = false
    @AppStorage("translationTemperature") var translationTemperature: Double = 0.2
    @AppStorage("maxOutputTokens") var maxOutputTokens: Int = 2048
    @AppStorage("lastRefreshAt") var lastRefreshAt: Double = 0

    var lastRefreshDate: Date? {
        get { lastRefreshAt > 0 ? Date(timeIntervalSince1970: lastRefreshAt) : nil }
        set { lastRefreshAt = newValue?.timeIntervalSince1970 ?? 0 }
    }
}
