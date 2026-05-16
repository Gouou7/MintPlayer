import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var theme: ThemeMode = .dark
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "theme"
    
    init() {
        loadSettings()
    }
    
    // 加载设置
    private func loadSettings() {
        if let themeString = userDefaults.string(forKey: themeKey), let savedTheme = ThemeMode(rawValue: themeString) {
            theme = savedTheme
        }
    }
    
    // 保存设置
    func saveSettings() {
        userDefaults.set(theme.rawValue, forKey: themeKey)
    }
    
    // 更新主题
    func updateTheme(_ newTheme: ThemeMode) {
        theme = newTheme
        saveSettings()
    }
}
