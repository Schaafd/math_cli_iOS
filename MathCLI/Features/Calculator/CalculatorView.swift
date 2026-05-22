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
    @StateObject private var viewModel: CalculatorViewModel
    @State private var historyManager: HistoryManager?
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showingRenameSheet = false
    @State private var sessionToRename: Session?
    @State private var newSessionName = ""

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
            .onAppear {
                setupCurrentSession()
            }
            .onChange(of: sessionManager.activeSession) { _, newSession in
                switchToSession(newSession)
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

                Button {
                    isInputFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("DismissKeyboardButton")

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

            // Quick action toolbar
            quickActionToolbar
        }
        .background(appTheme.surface)
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

    private var quickActionToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Common operations
                QuickActionButton(title: "+", operation: "add") {
                    insertOperation("add ")
                }

                QuickActionButton(title: "−", operation: "subtract") {
                    insertOperation("subtract ")
                }

                QuickActionButton(title: "×", operation: "multiply") {
                    insertOperation("multiply ")
                }

                QuickActionButton(title: "÷", operation: "divide") {
                    insertOperation("divide ")
                }

                QuickActionButton(title: "^", operation: "power") {
                    insertOperation("power ")
                }

                QuickActionButton(title: "√", operation: "sqrt") {
                    insertOperation("sqrt ")
                }

                QuickActionButton(title: "sin", operation: "sin") {
                    insertOperation("sin ")
                }

                QuickActionButton(title: "cos", operation: "cos") {
                    insertOperation("cos ")
                }

                QuickActionButton(title: "π", operation: "pi") {
                    insertOperation("pi")
                }

                QuickActionButton(title: "$", operation: "last result") {
                    insertOperation("$ ")
                }

                QuickActionButton(title: "|", operation: "chain") {
                    insertOperation(" | ")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(appTheme.secondarySurface)
    }

    private func insertOperation(_ text: String) {
        viewModel.inputText += text
        isInputFocused = true
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

    let title: String
    let operation: String
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
                Text(title)
                    .font(.system(.body, design: textFont.design))
                    .fontWeight(.semibold)
                    .foregroundColor(textColor.color ?? appTheme.commandText)

                Text(operation)
                    .font(.system(.caption2, design: textFont.design))
                    .foregroundColor(textColor.color ?? appTheme.secondaryText)
            }
            .frame(minWidth: 44)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(appTheme.surface)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CalculatorView()
        .modelContainer(for: HistoryEntry.self, inMemory: true)
}
