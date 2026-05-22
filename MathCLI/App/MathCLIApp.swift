//
//  MathCLIApp.swift
//  MathCLI
//
//  Main app entry point
//

import SwiftUI
import SwiftData
import OSLog

private let appLogger = Logger(subsystem: "com.codingzen.MathCLI", category: "App")

enum MathCLITheme: String, CaseIterable, Identifiable {
    case `default` = "default"
    case dark = "dark"
    case light = "light"
    case ocean = "ocean"
    case forest = "forest"
    case sunset = "sunset"
    case synthwave = "synthwave"
    case highContrast = "high-contrast"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .dark: return "Dark"
        case .light: return "Light"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        case .synthwave: return "Synthwave"
        case .highContrast: return "High Contrast"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .default, .ocean, .forest, .sunset:
            return nil
        case .dark, .synthwave, .highContrast:
            return .dark
        case .light:
            return .light
        }
    }

    var accent: Color {
        switch self {
        case .default: return .blue
        case .dark: return .cyan
        case .light: return .blue
        case .ocean: return Color(red: 0.0, green: 0.45, blue: 0.72)
        case .forest: return Color(red: 0.12, green: 0.48, blue: 0.27)
        case .sunset: return Color(red: 0.86, green: 0.28, blue: 0.18)
        case .synthwave: return Color(red: 0.96, green: 0.22, blue: 0.74)
        case .highContrast: return .yellow
        }
    }

    var background: Color {
        switch self {
        case .default: return Color(uiColor: .systemBackground)
        case .dark: return Color(red: 0.05, green: 0.06, blue: 0.08)
        case .light: return Color(red: 0.98, green: 0.98, blue: 0.96)
        case .ocean: return Color(red: 0.93, green: 0.98, blue: 1.0)
        case .forest: return Color(red: 0.94, green: 0.98, blue: 0.94)
        case .sunset: return Color(red: 1.0, green: 0.96, blue: 0.92)
        case .synthwave: return Color(red: 0.05, green: 0.02, blue: 0.12)
        case .highContrast: return .black
        }
    }

    var surface: Color {
        switch self {
        case .default: return Color(uiColor: .systemBackground)
        case .dark: return Color(red: 0.08, green: 0.09, blue: 0.12)
        case .light: return .white
        case .ocean: return Color(red: 0.84, green: 0.94, blue: 0.98)
        case .forest: return Color(red: 0.86, green: 0.94, blue: 0.86)
        case .sunset: return Color(red: 1.0, green: 0.89, blue: 0.82)
        case .synthwave: return Color(red: 0.12, green: 0.05, blue: 0.22)
        case .highContrast: return .black
        }
    }

    var secondarySurface: Color {
        switch self {
        case .default: return Color(uiColor: .secondarySystemBackground)
        case .dark: return Color(red: 0.10, green: 0.11, blue: 0.15)
        case .light: return Color(red: 0.93, green: 0.94, blue: 0.95)
        case .ocean: return Color(red: 0.76, green: 0.90, blue: 0.96)
        case .forest: return Color(red: 0.78, green: 0.90, blue: 0.78)
        case .sunset: return Color(red: 0.98, green: 0.82, blue: 0.72)
        case .synthwave: return Color(red: 0.18, green: 0.08, blue: 0.30)
        case .highContrast: return Color(red: 0.08, green: 0.08, blue: 0.08)
        }
    }

    var terminalBackground: Color {
        switch self {
        case .default: return Color(uiColor: .secondarySystemBackground)
        case .highContrast: return .black
        default: return secondarySurface
        }
    }

    var primaryText: Color {
        switch self {
        case .default: return Color(uiColor: .label)
        case .dark, .synthwave, .highContrast: return .white
        case .light: return Color(red: 0.08, green: 0.09, blue: 0.10)
        case .ocean: return Color(red: 0.02, green: 0.16, blue: 0.22)
        case .forest: return Color(red: 0.05, green: 0.18, blue: 0.08)
        case .sunset: return Color(red: 0.24, green: 0.10, blue: 0.06)
        }
    }

    var secondaryText: Color {
        switch self {
        case .default: return Color(uiColor: .secondaryLabel)
        case .dark, .synthwave: return Color(red: 0.70, green: 0.76, blue: 0.82)
        case .highContrast: return Color(red: 0.86, green: 0.86, blue: 0.86)
        case .light: return Color(red: 0.34, green: 0.38, blue: 0.42)
        case .ocean: return Color(red: 0.25, green: 0.38, blue: 0.43)
        case .forest: return Color(red: 0.28, green: 0.40, blue: 0.30)
        case .sunset: return Color(red: 0.48, green: 0.30, blue: 0.22)
        }
    }

    var commandText: Color {
        switch self {
        case .default: return Color(red: 0.0, green: 0.38, blue: 0.68)
        case .dark: return Color(red: 0.30, green: 0.84, blue: 1.0)
        case .light: return Color(red: 0.0, green: 0.29, blue: 0.57)
        case .ocean: return Color(red: 0.0, green: 0.32, blue: 0.50)
        case .forest: return Color(red: 0.0, green: 0.34, blue: 0.42)
        case .sunset: return Color(red: 0.60, green: 0.16, blue: 0.08)
        case .synthwave: return Color(red: 1.0, green: 0.44, blue: 0.90)
        case .highContrast: return .yellow
        }
    }

    var resultText: Color {
        switch self {
        case .default: return Color(red: 0.10, green: 0.45, blue: 0.16)
        case .dark: return Color(red: 0.39, green: 0.95, blue: 0.52)
        case .light: return Color(red: 0.08, green: 0.40, blue: 0.14)
        case .ocean: return Color(red: 0.02, green: 0.38, blue: 0.22)
        case .forest: return Color(red: 0.07, green: 0.34, blue: 0.12)
        case .sunset: return Color(red: 0.48, green: 0.28, blue: 0.00)
        case .synthwave: return Color(red: 0.35, green: 1.0, blue: 0.76)
        case .highContrast: return Color(red: 0.40, green: 1.0, blue: 0.40)
        }
    }

    var errorText: Color {
        switch self {
        case .dark, .synthwave, .highContrast: return Color(red: 1.0, green: 0.45, blue: 0.45)
        default: return Color(red: 0.72, green: 0.05, blue: 0.08)
        }
    }

    var infoText: Color {
        switch self {
        case .default: return Color(red: 0.55, green: 0.32, blue: 0.00)
        case .dark: return Color(red: 1.0, green: 0.74, blue: 0.34)
        case .light: return Color(red: 0.50, green: 0.30, blue: 0.00)
        case .ocean: return Color(red: 0.0, green: 0.36, blue: 0.44)
        case .forest: return Color(red: 0.30, green: 0.36, blue: 0.00)
        case .sunset: return Color(red: 0.62, green: 0.22, blue: 0.00)
        case .synthwave: return Color(red: 1.0, green: 0.74, blue: 0.30)
        case .highContrast: return .white
        }
    }

    /// Foreground color to use on top of `accent` backgrounds for legible contrast.
    var onAccent: Color {
        switch self {
        case .highContrast: return .black
        default: return .white
        }
    }
}

enum MathCLITextFont: String, CaseIterable, Identifiable {
    case monospaced = "monospaced"
    case system = "system"
    case rounded = "rounded"
    case serif = "serif"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monospaced: return "Monospaced"
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        }
    }

    var design: Font.Design {
        switch self {
        case .monospaced: return .monospaced
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }
}

enum MathCLITextColor: String, CaseIterable, Identifiable {
    case theme = "theme"
    case black = "black"
    case white = "white"
    case charcoal = "charcoal"
    case navy = "navy"
    case cyan = "cyan"
    case green = "green"
    case amber = "amber"
    case pink = "pink"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theme: return "Theme Matched"
        case .black: return "Black"
        case .white: return "White"
        case .charcoal: return "Charcoal"
        case .navy: return "Navy"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .amber: return "Amber"
        case .pink: return "Pink"
        }
    }

    var color: Color? {
        switch self {
        case .theme: return nil
        case .black: return .black
        case .white: return .white
        case .charcoal: return Color(red: 0.10, green: 0.11, blue: 0.13)
        case .navy: return Color(red: 0.0, green: 0.16, blue: 0.35)
        case .cyan: return Color(red: 0.0, green: 0.68, blue: 0.86)
        case .green: return Color(red: 0.07, green: 0.55, blue: 0.20)
        case .amber: return Color(red: 0.82, green: 0.46, blue: 0.0)
        case .pink: return Color(red: 0.82, green: 0.15, blue: 0.50)
        }
    }
}

enum CalculatorInputPanel: String, CaseIterable, Identifiable {
    case commandBar = "command-bar"
    case calculator = "calculator"
    case scientific = "scientific"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commandBar: return "Command Bar"
        case .calculator: return "Calculator"
        case .scientific: return "Scientific"
        }
    }

    var iconName: String {
        switch self {
        case .commandBar: return "rectangle.grid.1x2"
        case .calculator: return "plus.forwardslash.minus"
        case .scientific: return "function"
        }
    }
}

private struct MathCLIThemeKey: EnvironmentKey {
    static let defaultValue = MathCLITheme.default
}

extension EnvironmentValues {
    var mathCLITheme: MathCLITheme {
        get { self[MathCLIThemeKey.self] }
        set { self[MathCLIThemeKey.self] = newValue }
    }
}

@main
struct MathCLIApp: App {
    let modelContainer: ModelContainer
    @State private var sessionManager: SessionManager

    init() {
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITestMode")
            if isUITesting {
                Self.resetUITestDefaults()
            }

            // Initialize model container with both Session and HistoryEntry
            let container: ModelContainer
            if isUITesting {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Session.self, HistoryEntry.self, configurations: config)
            } else {
                container = try ModelContainer(for: Session.self, HistoryEntry.self)
            }
            modelContainer = container

            // Initialize session manager
            let manager = SessionManager(modelContext: container.mainContext)
            _sessionManager = State(wrappedValue: manager)
        } catch {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: Session.self, HistoryEntry.self,
                                                configurations: config)
            modelContainer = container

            let manager = SessionManager(modelContext: container.mainContext)
            _sessionManager = State(wrappedValue: manager)
            appLogger.error("Falling back to in-memory storage due to ModelContainer error: \(error.localizedDescription)")
        }
    }

    private static func resetUITestDefaults() {
        let defaults = UserDefaults.standard
        [
            "theme",
            "calculatorTextFont",
            "calculatorTextColor",
            "calculatorInputPanel",
            "calculatorPanelHeight",
            "pinnedCommands"
        ].forEach { key in
            defaults.removeObject(forKey: key)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(sessionManager)
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("theme") private var selectedTheme = MathCLITheme.default.rawValue
    @State private var selectedTab = 0

    private var theme: MathCLITheme {
        MathCLITheme(rawValue: selectedTheme) ?? .default
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorView()
                .tabItem {
                    Label("Calculator", systemImage: "function")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)

            OperationBrowserView()
                .tabItem {
                    Label("Operations", systemImage: "list.bullet")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .environment(\.mathCLITheme, theme)
        .preferredColorScheme(theme.preferredColorScheme)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .toolbarBackground(theme.secondarySurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
