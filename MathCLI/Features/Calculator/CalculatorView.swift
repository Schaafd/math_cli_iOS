//
//  CalculatorView.swift
//  MathCLI
//
//  Main calculator view with hybrid terminal-modern UI
//

import SwiftUI
import SwiftData
import UIKit

struct CalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.mathCLITheme) private var appTheme
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue
    @AppStorage("calculatorInputPanel") private var calculatorInputPanel = CalculatorInputPanel.commandBar.rawValue
    @AppStorage("pinnedCommands") private var pinnedCommandsData = ""
    @StateObject private var viewModel: CalculatorViewModel
    @State private var historyManager: HistoryManager?
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showingRenameSheet = false
    @State private var showingCommandDrawer = false
    @State private var selectedCommandDetail: CommandShortcut?
    @State private var sessionToRename: Session?
    @State private var newSessionName = ""
    @State private var cachedPinnedCommandNames: [String] = []

    private let defaultCommandNames = ["add", "subtract", "multiply", "divide", "power"]
    private let registry = OperationRegistry.shared

    init() {
        _viewModel = StateObject(wrappedValue: CalculatorViewModel())
    }

    // Only show sessions that are active (open in tabs)
    private var activeSessions: [Session] {
        sessionManager.sessions.filter { $0.isActive }
    }

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    private var inputPanel: CalculatorInputPanel {
        CalculatorInputPanel(rawValue: calculatorInputPanel) ?? .commandBar
    }

    private var pinnedCommandNames: [String] {
        cachedPinnedCommandNames.isEmpty ? defaultCommandNames : cachedPinnedCommandNames
    }

    private var pinnedCommands: [CommandShortcut] {
        pinnedCommandNames.compactMap { makeCommandShortcut(name: $0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Session tabs at the top
                sessionTabBar

                Divider()

                // Terminal-style output area
                terminalOutput

                Divider()

                // Modern input controls
                inputArea
            }
            .background(appTheme.background)
            .navigationTitle("Math CLI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New Session", systemImage: "plus.circle") {
                            createNewSession()
                        }
                        Divider()
                        Button("Clear Output", systemImage: "trash") {
                            viewModel.outputLines.removeAll()
                        }
                        Button("Show Variables", systemImage: "x.squareroot") {
                            viewModel.inputText = "vars"
                            viewModel.executeCommand()
                        }
                        Button("Show Help", systemImage: "questionmark.circle") {
                            viewModel.inputText = "help"
                            viewModel.executeCommand()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("CalculatorMenuButton")
                }
            }
            .sheet(isPresented: $showingRenameSheet) {
                renameSessionSheet
            }
            .sheet(isPresented: $showingCommandDrawer) {
                CommandDrawerView(
                    pinnedCommandNames: pinnedCommandNames,
                    defaultCommandNames: defaultCommandNames,
                    onUse: { command in
                        insertCommand(command.name)
                        showingCommandDrawer = false
                    },
                    onTogglePin: { command in
                        togglePinnedCommand(command.name)
                    },
                    onResetPins: {
                        resetPinnedCommands()
                    }
                )
                .environment(\.mathCLITheme, appTheme)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedCommandDetail) { command in
                CommandDetailSheet(command: command)
                    .environment(\.mathCLITheme, appTheme)
                    .presentationDetents([.height(320), .medium])
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                setupCurrentSession()
                cachedPinnedCommandNames = decodePinnedCommands()
            }
            .onChange(of: sessionManager.activeSession) { _, newSession in
                switchToSession(newSession)
            }
            .onChange(of: pinnedCommandsData) { _, _ in
                cachedPinnedCommandNames = decodePinnedCommands()
            }
        }
    }

    // MARK: - Session Tab Bar

    private var sessionTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(activeSessions) { session in
                    SessionTab(
                        session: session,
                        isActive: session.id == sessionManager.activeSession?.id,
                        onTap: {
                            sessionManager.switchToSession(session)
                        },
                        onClose: {
                            sessionManager.closeSession(session)
                        },
                        onRename: {
                            sessionToRename = session
                            newSessionName = session.name
                            showingRenameSheet = true
                        }
                    )
                }

                // Add new session button
                Button {
                    createNewSession()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .cornerRadius(6)
                }
                .accessibilityIdentifier("NewSessionButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 50)
        .background(appTheme.secondarySurface)
    }

    private var renameSessionSheet: some View {
        NavigationStack {
            Form {
                TextField("Session Name", text: $newSessionName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("RenameSessionInput")
            }
            .navigationTitle("Rename Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingRenameSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let session = sessionToRename, !newSessionName.isEmpty {
                            sessionManager.renameSession(session, newName: newSessionName)
                        }
                        showingRenameSheet = false
                    }
                    .disabled(newSessionName.isEmpty)
                    .accessibilityIdentifier("SaveRenameSessionButton")
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Helper Methods

    private func setupCurrentSession() {
        // Initialize history manager if needed
        if historyManager == nil {
            historyManager = HistoryManager(modelContext: modelContext)
        }

        if let session = sessionManager.activeSession {
            historyManager?.setCurrentSession(session)
            viewModel.historyManager = historyManager
            VariableStore.shared.setSession(session.id)
            FunctionRegistry.shared.setSession(session.id)

            // Load session history to restore output lines
            viewModel.loadSessionHistory(session)
        }
    }

    private func switchToSession(_ session: Session?) {
        guard let session = session else { return }

        // Initialize history manager if needed
        if historyManager == nil {
            historyManager = HistoryManager(modelContext: modelContext)
        }

        // Switch history manager to new session
        historyManager?.setCurrentSession(session)
        viewModel.historyManager = historyManager

        // Load new session's variables and functions
        VariableStore.shared.setSession(session.id)
        FunctionRegistry.shared.setSession(session.id)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Load session history to restore output lines
        viewModel.loadSessionHistory(session)

        // Add session switch notification
        viewModel.addOutputLine("📋 Switched to \(session.name)", type: .info)

        // Show variable count if any
        let vars = VariableStore.shared.getAllVariables()
        if !vars.isEmpty {
            viewModel.addOutputLine("\(vars.count) variable\(vars.count == 1 ? "" : "s") loaded", type: .info)
        }

        viewModel.addOutputLine("", type: .info)

        // Refocus input
        isInputFocused = true
    }

    private func createNewSession() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        _ = sessionManager.createSession()
        if let newSession = sessionManager.activeSession {
            switchToSession(newSession)
        }
    }

    // MARK: - Terminal Output

    private var terminalOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.outputLines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            // Timestamp
                            Text(line.timestamp, style: .time)
                                .font(.system(.caption, design: textFont.design))
                                .foregroundColor(textColor.color ?? appTheme.secondaryText)
                                .frame(width: 60, alignment: .leading)

                            // Output text
                            Text(line.text)
                                .font(.system(.body, design: textFont.design))
                                .foregroundColor(outputColor(for: line.type))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .id(line.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(appTheme.terminalBackground)
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: viewModel.outputLines.count) { _, _ in
                if let lastLine = viewModel.outputLines.last {
                    withAnimation {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            // Suggestions
            if viewModel.showSuggestions {
                suggestionBar
            }

            // Input field
            HStack(spacing: 12) {
                // Prompt indicator
                Text(">")
                    .font(.system(.title2, design: textFont.design))
                    .foregroundColor(textColor.color ?? appTheme.commandText)

                // Text field
                TextField("Enter operation...", text: $viewModel.inputText)
                    .font(.system(.body, design: textFont.design))
                    .foregroundColor(textColor.color ?? appTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("CalculatorInput")
                    .focused($isInputFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                        }
                    }
                    .onSubmit {
                        viewModel.executeCommand()
                        isInputFocused = true
                    }
                    .onChange(of: viewModel.inputText) { _, _ in
                        viewModel.updateSuggestions()
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                showInputCommandHelp()
                            }
                    )

                Menu {
                    Button("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down") {
                        isInputFocused = false
                    }

                    Divider()

                    ForEach(CalculatorInputPanel.allCases) { panel in
                        Button {
                            withAnimation(.snappy(duration: 0.28)) {
                                calculatorInputPanel = panel.rawValue
                            }
                        } label: {
                            Label(panel.displayName, systemImage: panel.iconName)
                        }
                    }

                    Divider()

                    Button("Command Drawer", systemImage: "square.grid.2x2") {
                        withAnimation(.snappy(duration: 0.28)) {
                            showingCommandDrawer = true
                        }
                    }
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .menuOrder(.fixed)
                .accessibilityIdentifier("KeyboardMenuButton")

                // Execute button
                Button {
                    viewModel.executeCommand()
                    isInputFocused = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.inputText.isEmpty ? .gray : .blue)
                }
                .disabled(viewModel.inputText.isEmpty)
                .accessibilityIdentifier("ExecuteButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.45) {
                showInputCommandHelp()
            }

            inputPanelView
        }
        .background(appTheme.surface)
        .animation(.snappy(duration: 0.28), value: inputPanel)
        .animation(.snappy(duration: 0.28), value: pinnedCommandNames)
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Suggestion Bar

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.selectSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(.footnote, design: textFont.design))
                            .foregroundColor(textColor.color ?? appTheme.commandText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(appTheme.accent.opacity(0.16))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(appTheme.secondarySurface)
    }

    // MARK: - Quick Action Toolbar

    private var inputPanelView: some View {
        VStack(spacing: 0) {
            switch inputPanel {
            case .commandBar:
                EmptyView()
            case .calculator:
                CalculatorKeypadView(
                    mode: .standard,
                    onInsert: insertCalculatorToken,
                    onBackspace: deleteLastInputCharacter,
                    onClear: clearInput,
                    onExecute: executeInput
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            case .scientific:
                CalculatorKeypadView(
                    mode: .scientific,
                    onInsert: insertCalculatorToken,
                    onBackspace: deleteLastInputCharacter,
                    onClear: clearInput,
                    onExecute: executeInput
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            quickActionToolbar
        }
    }

    private var quickActionToolbar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pinnedCommands) { command in
                        QuickActionButton(command: command) {
                            insertCommand(command.name)
                        }
                        .contextMenu {
                            Button("Unpin", systemImage: "pin.slash") {
                                togglePinnedCommand(command.name)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.leading, 16)
            }

            Button {
                withAnimation(.snappy(duration: 0.28)) {
                    showingCommandDrawer = true
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(.body, design: textFont.design))
                        .fontWeight(.semibold)

                    Text("browse")
                        .font(.system(.caption2, design: textFont.design))
                }
                .foregroundColor(textColor.color ?? appTheme.commandText)
                .frame(width: 66, height: 56)
                .background(appTheme.surface)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("CommandDrawerButton")
            .padding(.trailing, 16)
        }
        .background(appTheme.secondarySurface)
    }

    private func insertCommand(_ commandName: String) {
        viewModel.inputText += commandInsertionText(for: commandName)
        isInputFocused = true
    }

    private func insertCalculatorToken(_ token: String) {
        viewModel.inputText += token
        isInputFocused = true
        viewModel.updateSuggestions()
    }

    private func deleteLastInputCharacter() {
        guard !viewModel.inputText.isEmpty else { return }
        viewModel.inputText.removeLast()
        viewModel.updateSuggestions()
    }

    private func clearInput() {
        viewModel.inputText = ""
        viewModel.updateSuggestions()
    }

    private func executeInput() {
        viewModel.executeCommand()
        isInputFocused = true
    }

    private func commandInsertionText(for commandName: String) -> String {
        switch commandName {
        case "pi", "e", "golden":
            return commandName
        default:
            return commandName + " "
        }
    }

    private func makeCommandShortcut(name: String) -> CommandShortcut? {
        guard let operation = registry.getOperation(name: name) else {
            return nil
        }
        return CommandShortcut(name: name, operation: operation)
    }

    private func showInputCommandHelp() {
        guard let command = commandDetailForCurrentInput() else { return }
        selectedCommandDetail = command
    }

    private func commandDetailForCurrentInput() -> CommandShortcut? {
        let input = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        if let operatorCommand = commandForLastOperator(in: input) {
            return operatorCommand
        }

        let tokens = input
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        for token in tokens.reversed() {
            if let command = makeCommandShortcut(name: token.lowercased()) {
                return command
            }
        }

        return nil
    }

    private func commandForLastOperator(in input: String) -> CommandShortcut? {
        let operatorMap: [Character: String] = [
            "+": "add",
            "-": "subtract",
            "*": "multiply",
            "×": "multiply",
            "/": "divide",
            "÷": "divide",
            "^": "power",
            "%": "mod"
        ]

        for character in input.reversed() {
            if let commandName = operatorMap[character] {
                return makeCommandShortcut(name: commandName)
            }
        }
        return nil
    }

    private func decodePinnedCommands() -> [String] {
        guard let data = pinnedCommandsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded.filter { registry.getOperation(name: $0) != nil }
    }

    private func savePinnedCommands(_ names: [String]) {
        let uniqueNames = names.reduce(into: [String]()) { result, name in
            if !result.contains(name), registry.getOperation(name: name) != nil {
                result.append(name)
            }
        }

        if let data = try? JSONEncoder().encode(uniqueNames),
           let text = String(data: data, encoding: .utf8) {
            pinnedCommandsData = text
        }
    }

    private func togglePinnedCommand(_ name: String) {
        var names = pinnedCommandNames
        if names.contains(name) {
            names.removeAll { $0 == name }
        } else {
            names.append(name)
        }

        withAnimation(.snappy(duration: 0.28)) {
            savePinnedCommands(names)
        }
    }

    private func resetPinnedCommands() {
        withAnimation(.snappy(duration: 0.28)) {
            savePinnedCommands(defaultCommandNames)
        }
    }

    private func outputColor(for type: CalculatorViewModel.OutputLine.LineType) -> Color {
        if let override = textColor.color {
            return type == .error ? appTheme.errorText : override
        }

        switch type {
        case .command: return appTheme.commandText
        case .result: return appTheme.resultText
        case .error: return appTheme.errorText
        case .info: return appTheme.infoText
        }
    }
}

// MARK: - Command Shortcuts

struct CommandShortcut: Identifiable, Hashable {
    let name: String
    let title: String
    let subtitle: String
    let symbol: String
    let category: OperationCategory
    let help: String
    let arguments: [String]
    let isVariadic: Bool

    var id: String { name }

    init(name: String, operation: any MathOperation.Type) {
        self.name = name
        self.title = CommandShortcut.symbol(for: name)
        self.subtitle = name
        self.symbol = CommandShortcut.symbol(for: name)
        self.category = operation.category
        self.help = operation.help
        self.arguments = operation.arguments
        self.isVariadic = operation.isVariadic
    }

    private static func symbol(for name: String) -> String {
        switch name {
        case "add": return "+"
        case "subtract": return "-"
        case "multiply": return "×"
        case "divide": return "÷"
        case "power": return "^"
        case "sqrt": return "√"
        case "factorial": return "!"
        case "mod": return "%"
        case "pi": return "π"
        case "e": return "e"
        case "sin", "cos", "tan", "log", "ln", "exp", "abs", "min", "max", "mean", "median", "sum":
            return name
        default:
            return String(name.prefix(3))
        }
    }
}

struct CommandDrawerView: View {
    @Environment(\.mathCLITheme) private var appTheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue

    let pinnedCommandNames: [String]
    let defaultCommandNames: [String]
    let onUse: (CommandShortcut) -> Void
    let onTogglePin: (CommandShortcut) -> Void
    let onResetPins: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: OperationCategory?
    @State private var selectedCommandDetail: CommandShortcut?

    private let registry = OperationRegistry.shared

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    private var categories: [OperationCategory] {
        registry.getAvailableCategories()
    }

    private var commands: [CommandShortcut] {
        registry.getAllOperationNames().compactMap { name in
            guard let operation = registry.getOperation(name: name) else { return nil }
            return CommandShortcut(name: name, operation: operation)
        }
    }

    private var filteredCommands: [CommandShortcut] {
        commands.filter { command in
            let matchesSearch = searchText.isEmpty ||
                command.name.localizedCaseInsensitiveContains(searchText) ||
                command.help.localizedCaseInsensitiveContains(searchText) ||
                command.category.rawValue.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || command.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                drawerHeader
                categoryStrip

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredCommands) { command in
                            CommandDrawerCard(
                                command: command,
                                isPinned: pinnedCommandNames.contains(command.name),
                                onUse: {
                                    onUse(command)
                                },
                                onTogglePin: {
                                    withAnimation(.snappy(duration: 0.24)) {
                                        onTogglePin(command)
                                    }
                                },
                                onShowDetails: {
                                    selectedCommandDetail = command
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(appTheme.background)
            .navigationTitle("Command Drawer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        onResetPins()
                    }
                }
            }
            .sheet(item: $selectedCommandDetail) { command in
                CommandDetailSheet(command: command)
                    .environment(\.mathCLITheme, appTheme)
                    .presentationDetents([.height(320), .medium])
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var drawerHeader: some View {
        VStack(spacing: 10) {
            TextField("Search commands", text: $searchText)
                .font(.system(.body, design: textFont.design))
                .foregroundColor(textColor.color ?? appTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(appTheme.surface)
                .cornerRadius(8)
                .accessibilityIdentifier("CommandDrawerSearch")

            HStack {
                Text("\(pinnedCommandNames.count) pinned")
                    .font(.caption)
                    .foregroundColor(appTheme.secondaryText)

                Spacer()

                Text("Default: \(defaultCommandNames.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(appTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(appTheme.secondarySurface)
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(title: "All", category: nil)

                ForEach(categories, id: \.self) { category in
                    categoryButton(title: category.rawValue, category: category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(appTheme.background)
    }

    private func categoryButton(title: String, category: OperationCategory?) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(selectedCategory == category ? .semibold : .regular)
                .foregroundColor(selectedCategory == category ? appTheme.onAccent : appTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selectedCategory == category ? appTheme.accent : appTheme.surface)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CommandDrawerCard: View {
    @Environment(\.mathCLITheme) private var appTheme
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue

    let command: CommandShortcut
    let isPinned: Bool
    let onUse: () -> Void
    let onTogglePin: () -> Void
    let onShowDetails: () -> Void

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onShowDetails) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(command.symbol)
                                .font(.system(.title3, design: textFont.design))
                                .fontWeight(.bold)
                                .foregroundColor(textColor.color ?? appTheme.commandText)

                            Text(command.name)
                                .font(.system(.caption, design: textFont.design))
                                .foregroundColor(textColor.color ?? appTheme.primaryText)
                                .lineLimit(1)
                        }

                        Text(command.help)
                            .font(.caption2)
                            .foregroundColor(appTheme.secondaryText)
                            .lineLimit(2)
                            .frame(minHeight: 32, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("CommandCard_\(command.name)")

                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundColor(isPinned ? appTheme.accent : appTheme.secondaryText)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("PinCommand_\(command.name)")
            }

            Button(action: onUse) {
                Label("Use", systemImage: "arrow.turn.down.left")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundColor(appTheme.onAccent)
                    .background(appTheme.accent)
                    .cornerRadius(7)
            }
            .accessibilityIdentifier("UseCommand_\(command.name)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(appTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPinned ? appTheme.accent.opacity(0.55) : appTheme.secondaryText.opacity(0.12), lineWidth: 1)
        )
    }
}

struct CommandDetailSheet: View {
    @Environment(\.mathCLITheme) private var appTheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue

    let command: CommandShortcut

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(command.symbol)
                            .font(.system(.largeTitle, design: textFont.design))
                            .fontWeight(.bold)
                            .foregroundColor(textColor.color ?? appTheme.commandText)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(command.name)
                                .font(.system(.title3, design: textFont.design))
                                .fontWeight(.semibold)
                                .foregroundColor(textColor.color ?? appTheme.primaryText)

                            Text(command.category.rawValue)
                                .font(.caption)
                                .foregroundColor(appTheme.secondaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Help")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(appTheme.secondaryText)

                        Text(command.help)
                            .font(.system(.body, design: textFont.design))
                            .foregroundColor(textColor.color ?? appTheme.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Parameters")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(appTheme.secondaryText)

                        if command.arguments.isEmpty {
                            Text("No parameters")
                                .font(.system(.body, design: textFont.design))
                                .foregroundColor(appTheme.secondaryText)
                        } else {
                            Text(command.arguments.joined(separator: ", "))
                                .font(.system(.body, design: textFont.design))
                                .foregroundColor(textColor.color ?? appTheme.primaryText)
                        }

                        if command.isVariadic {
                            Text("Accepts a variable number of parameters.")
                                .font(.caption)
                                .foregroundColor(appTheme.infoText)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(appTheme.background)
            .navigationTitle("Command Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("CommandDetailSheet_\(command.name)")
    }
}

// MARK: - Calculator Keypad

enum CalculatorKeypadMode {
    case standard
    case scientific
}

struct CalculatorKeypadView: View {
    @Environment(\.mathCLITheme) private var appTheme
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue

    let mode: CalculatorKeypadMode
    let onInsert: (String) -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void
    let onExecute: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    private var keys: [CalculatorKey] {
        switch mode {
        case .standard:
            return [
                .insert("7", "7"), .insert("8", "8"), .insert("9", "9"), .insert("÷", " / "),
                .insert("4", "4"), .insert("5", "5"), .insert("6", "6"), .insert("×", " * "),
                .insert("1", "1"), .insert("2", "2"), .insert("3", "3"), .insert("-", " - "),
                .insert("0", "0"), .insert(".", "."), .insert("(", "("), .insert(")", ")"),
                .clear, .backspace, .insert("+", " + "), .execute
            ]
        case .scientific:
            return [
                .insert("sin", "sin("), .insert("cos", "cos("), .insert("tan", "tan("), .insert("√", "sqrt("),
                .insert("log", "log("), .insert("ln", "ln("), .insert("exp", "exp("), .insert("^", " ^ "),
                .insert("π", "pi"), .insert("e", "e"), .insert("abs", "abs("), .insert("!", "!"),
                .insert("7", "7"), .insert("8", "8"), .insert("9", "9"), .insert("÷", " / "),
                .insert("4", "4"), .insert("5", "5"), .insert("6", "6"), .insert("×", " * "),
                .insert("1", "1"), .insert("2", "2"), .insert("3", "3"), .insert("-", " - "),
                .insert("0", "0"), .insert(".", "."), .insert("ans", "ans"), .insert("+", " + "),
                .clear, .backspace, .insert("%", " % "), .execute
            ]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(keys) { key in
                Button {
                    handle(key)
                } label: {
                    Text(key.title)
                        .font(.system(.body, design: textFont.design))
                        .fontWeight(key.isPrimary ? .bold : .semibold)
                        .foregroundColor(key.isPrimary ? appTheme.onAccent : textColor.color ?? appTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(key.isPrimary ? appTheme.accent : appTheme.secondarySurface)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("CalculatorKey_\(key.accessibilityName)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(appTheme.surface)
    }

    private func handle(_ key: CalculatorKey) {
        switch key {
        case .insert(_, let token):
            onInsert(token)
        case .clear:
            onClear()
        case .backspace:
            onBackspace()
        case .execute:
            onExecute()
        }
    }
}

enum CalculatorKey: Identifiable, Hashable {
    case insert(String, String)
    case clear
    case backspace
    case execute

    var id: String {
        switch self {
        case .insert(let title, let token): return "\(title)-\(token)"
        case .clear: return "clear"
        case .backspace: return "backspace"
        case .execute: return "execute"
        }
    }

    var title: String {
        switch self {
        case .insert(let title, _): return title
        case .clear: return "C"
        case .backspace: return "⌫"
        case .execute: return "↵"
        }
    }

    var accessibilityName: String {
        title
            .replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: "-", with: "minus")
            .replacingOccurrences(of: "×", with: "multiply")
            .replacingOccurrences(of: "÷", with: "divide")
            .replacingOccurrences(of: "√", with: "sqrt")
            .replacingOccurrences(of: "⌫", with: "backspace")
            .replacingOccurrences(of: "↵", with: "execute")
    }

    var isPrimary: Bool {
        switch self {
        case .execute: return true
        default: return false
        }
    }

    private func outputColor(for type: CalculatorViewModel.OutputLine.LineType) -> Color {
        if let override = textColor.color {
            return type == .error ? appTheme.errorText : override
        }

        switch type {
        case .command: return appTheme.commandText
        case .result: return appTheme.resultText
        case .error: return appTheme.errorText
        case .info: return appTheme.infoText
        }
    }
}

// MARK: - Session Tab

struct SessionTab: View {
    let session: Session
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Session name
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(.caption, design: .default))
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("SessionTab_\(session.name)")

                    Text("\(session.entryCount) entries")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename", systemImage: "pencil") {
                    onRename()
                }
                Button("Close", systemImage: "xmark", role: .destructive) {
                    onClose()
                }
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    @Environment(\.mathCLITheme) private var appTheme
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue

    let command: CommandShortcut
    let action: () -> Void

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(command.title)
                    .font(.system(.body, design: textFont.design))
                    .fontWeight(.semibold)
                    .foregroundColor(textColor.color ?? appTheme.commandText)

                Text(command.subtitle)
                    .font(.system(.caption2, design: textFont.design))
                    .foregroundColor(textColor.color ?? appTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(minWidth: 74, minHeight: 56)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(appTheme.surface)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("QuickCommand_\(command.name)")
    }
}

// MARK: - Preview

#Preview {
    CalculatorView()
        .modelContainer(for: HistoryEntry.self, inMemory: true)
}
