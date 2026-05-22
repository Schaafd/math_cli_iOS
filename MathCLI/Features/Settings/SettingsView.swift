//
//  SettingsView.swift
//  MathCLI
//
//  App settings and preferences
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mathCLITheme) private var appTheme
    @Query(sort: \Session.createdAt, order: .reverse) private var allSessions: [Session]

    @AppStorage("decimalPlaces") private var decimalPlaces = 6
    @AppStorage("historyLimit") private var historyLimit = 1000
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("enableSuggestions") private var enableSuggestions = true
    @AppStorage("theme") private var selectedTheme = "default"
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue
    @State private var exportDocument: MathCLITextDocument?
    @State private var showImporter = false
    @State private var showClearVariablesConfirmation = false
    @State private var showClearFunctionsConfirmation = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Display Settings
                Section("Display") {
                    Stepper("Decimal Places: \(decimalPlaces)", value: $decimalPlaces, in: 0...15)

                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(MathCLITheme.allCases) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }

                    Picker("Calculator Font", selection: $calculatorTextFont) {
                        ForEach(MathCLITextFont.allCases) { font in
                            Text(font.displayName).tag(font.rawValue)
                        }
                    }

                    Picker("Calculator Text Color", selection: $calculatorTextColor) {
                        ForEach(MathCLITextColor.allCases) { textColor in
                            HStack {
                                if let color = textColor.color {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(.secondary.opacity(0.35), lineWidth: 1)
                                        )
                                }
                                Text(textColor.displayName)
                            }
                            .tag(textColor.rawValue)
                        }
                    }
                }
                .listRowBackground(appTheme.surface)

                // Calculator Settings
                Section("Calculator") {
                    Toggle("Show Suggestions", isOn: $enableSuggestions)
                    Toggle("Haptic Feedback", isOn: $enableHaptics)

                    Stepper("History Limit: \(historyLimit)", value: $historyLimit, in: 100...5000, step: 100)
                }
                .listRowBackground(appTheme.surface)

                // Data Management
                Section("Data") {
                    Button("Export App Data") {
                        exportAppData()
                    }
                    .accessibilityIdentifier("ExportAppDataButton")

                    Button("Import App Data") {
                        showImporter = true
                    }
                    .accessibilityIdentifier("ImportAppDataButton")

                    Button("Clear All Variables", role: .destructive) {
                        showClearVariablesConfirmation = true
                    }
                    .accessibilityIdentifier("ClearAllVariablesButton")

                    Button("Clear All Functions", role: .destructive) {
                        showClearFunctionsConfirmation = true
                    }
                    .accessibilityIdentifier("ClearAllFunctionsButton")
                }
                .listRowBackground(appTheme.surface)

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Operations")
                        Spacer()
                        Text("\(OperationRegistry.shared.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Documentation")
                        Spacer()
                        Text("README.md")
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(appTheme.surface)
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(appTheme.background)
            .alert(
                "Clear all variables?",
                isPresented: $showClearVariablesConfirmation,
            ) {
                Button("Clear All Variables", role: .destructive) {
                    clearVariables()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all variables in the current session.")
            }
            .alert(
                "Clear all functions?",
                isPresented: $showClearFunctionsConfirmation,
            ) {
                Button("Clear All Functions", role: .destructive) {
                    clearFunctions()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all user-defined functions in the current session.")
            }
            .fileExporter(
                isPresented: Binding(
                    get: { exportDocument != nil },
                    set: { if !$0 { exportDocument = nil } }
                ),
                document: exportDocument,
                contentType: .json,
                defaultFilename: "MathCLI-AppData.json"
            ) { result in
                switch result {
                case .success:
                    statusMessage = "App data exported."
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importAppData(from: result)
            }
            .alert("Done", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusMessage ?? "")
            }
            .alert("Settings Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func exportAppData() {
        do {
            exportDocument = try makeMathCLIAppDataDocument(sessions: allSessions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importAppData(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(MathCLIAppDataArchive.self, from: data)

            VariableStore.shared.importVariables(archive.variables, merge: true)
            for function in archive.functions {
                FunctionRegistry.shared.define(
                    name: function.name,
                    parameters: function.parameters,
                    body: function.body,
                    help: function.help
                )
            }

            importSessions(archive.sessions)
            statusMessage = "Imported \(archive.variables.count) variables, \(archive.functions.count) functions, and \(archive.sessions.count) sessions."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importSessions(_ snapshots: [MathCLISessionSnapshot]) {
        for snapshot in snapshots {
            let session = Session(
                name: "\(snapshot.name) (Imported)",
                createdAt: snapshot.createdAt,
                isActive: false
            )
            modelContext.insert(session)

            for entrySnapshot in snapshot.commands {
                let entry = HistoryEntry(
                    command: entrySnapshot.command,
                    result: entrySnapshot.result,
                    timestamp: entrySnapshot.timestamp,
                    isBookmarked: entrySnapshot.isBookmarked,
                    bookmarkName: entrySnapshot.bookmarkName,
                    session: session
                )
                modelContext.insert(entry)
                session.entries.append(entry)
            }
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearVariables() {
        VariableStore.shared.clearAll()
        statusMessage = "Variables cleared."
    }

    private func clearFunctions() {
        FunctionRegistry.shared.clearAll()
        statusMessage = "Functions cleared."
    }
}

#Preview {
    SettingsView()
}
