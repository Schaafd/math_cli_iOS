//
//  HistoryView.swift
//  MathCLI
//
//  View for browsing calculation history organized by sessions
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct MathCLITextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            text = ""
            return
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct MathCLISessionArchive: Codable {
    let version: Int
    let exportedAt: Date
    let sessions: [MathCLISessionSnapshot]

    @MainActor
    init(sessions: [Session]) {
        self.version = 1
        self.exportedAt = Date()
        self.sessions = sessions
            .sorted { $0.createdAt < $1.createdAt }
            .map(MathCLISessionSnapshot.init(session:))
    }
}

struct MathCLISessionSnapshot: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let isActive: Bool
    let commands: [MathCLIHistoryEntrySnapshot]

    @MainActor
    init(session: Session) {
        self.id = session.id
        self.name = session.name
        self.createdAt = session.createdAt
        self.isActive = session.isActive
        self.commands = session.entries
            .sorted { $0.timestamp < $1.timestamp }
            .map(MathCLIHistoryEntrySnapshot.init(entry:))
    }
}

struct MathCLIHistoryEntrySnapshot: Codable {
    let id: UUID
    let command: String
    let result: String
    let timestamp: Date
    let isBookmarked: Bool
    let bookmarkName: String?

    @MainActor
    init(entry: HistoryEntry) {
        self.id = entry.id
        self.command = entry.command
        self.result = entry.result
        self.timestamp = entry.timestamp
        self.isBookmarked = entry.isBookmarked
        self.bookmarkName = entry.bookmarkName
    }
}

struct MathCLIAppDataArchive: Codable {
    let version: Int
    let exportedAt: Date
    let variables: [String: String]
    let functions: [UserFunction]
    let sessions: [MathCLISessionSnapshot]
}

enum MathCLIExportFormat {
    case json
    case markdown
}

@MainActor
func makeMathCLIJSONDocument(from sessions: [Session]) throws -> MathCLITextDocument {
    let archive = MathCLISessionArchive(sessions: sessions)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(archive)
    return MathCLITextDocument(text: String(decoding: data, as: UTF8.self))
}

@MainActor
func makeMathCLIMarkdownDocument(from sessions: [Session]) -> MathCLITextDocument {
    let dateFormatter = ISO8601DateFormatter()
    var markdown = "# MathCLI Sessions\n\n"
    markdown += "Exported: \(dateFormatter.string(from: Date()))\n\n"

    for session in sessions.sorted(by: { $0.createdAt < $1.createdAt }) {
        markdown += "## \(session.name)\n\n"
        markdown += "- ID: `\(session.id.uuidString)`\n"
        markdown += "- Created: \(dateFormatter.string(from: session.createdAt))\n"
        markdown += "- Active: \(session.isActive ? "yes" : "no")\n\n"

        let entries = session.entries.sorted { $0.timestamp < $1.timestamp }
        if entries.isEmpty {
            markdown += "_No commands recorded._\n\n"
            continue
        }

        for entry in entries {
            markdown += "### \(dateFormatter.string(from: entry.timestamp))\n\n"
            if entry.isBookmarked {
                markdown += "- Bookmark: \(entry.bookmarkName ?? "yes")\n"
            }
            markdown += "```text\n\(entry.command)\n```\n\n"
            markdown += "Result:\n\n```text\n\(entry.result)\n```\n\n"
        }
    }

    return MathCLITextDocument(text: markdown)
}

@MainActor
func makeMathCLIAppDataDocument(sessions: [Session]) throws -> MathCLITextDocument {
    let archive = MathCLIAppDataArchive(
        version: 1,
        exportedAt: Date(),
        variables: VariableStore.shared.exportVariables(),
        functions: FunctionRegistry.shared.getAllFunctions(),
        sessions: sessions.sorted { $0.createdAt < $1.createdAt }.map(MathCLISessionSnapshot.init(session:))
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(archive)
    return MathCLITextDocument(text: String(decoding: data, as: UTF8.self))
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager
    @Query(sort: \Session.createdAt, order: .reverse) private var allSessions: [Session]
    @State private var selectedSession: Session?
    @State private var searchText = ""
    @State private var showBookmarksOnly = false
    @State private var exportDocument: MathCLITextDocument?
    @State private var exportFilename = "MathCLI-Sessions.json"
    @State private var exportContentType: UTType = .json
    @State private var showClearInactiveConfirmation = false
    @State private var exportErrorMessage: String?

    var activeSessions: [Session] {
        allSessions.filter { $0.isActive }
    }

    var inactiveSessions: [Session] {
        allSessions.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            List {
                // Active Sessions Section
                if !activeSessions.isEmpty {
                    Section("Active Session") {
                        ForEach(activeSessions) { session in
                            SessionRow(
                                session: session,
                                isActive: true,
                                onTap: {
                                    selectedSession = session
                                },
                                onReopen: nil
                            )
                        }
                    }
                }

                // Inactive Sessions Section
                if !inactiveSessions.isEmpty {
                    Section("Past Sessions") {
                        ForEach(inactiveSessions) { session in
                            SessionRow(
                                session: session,
                                isActive: false,
                                onTap: {
                                    selectedSession = session
                                },
                                onReopen: {
                                    reopenSession(session)
                                }
                            )
                        }
                        .onDelete(perform: deleteInactiveSessions)
                    }
                }

                // Empty state
                if allSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Start calculating to create your first session")
                    )
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            exportAllSessions(format: .json)
                        } label: {
                            Label("Export All as JSON", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            exportAllSessions(format: .markdown)
                        } label: {
                            Label("Export All as Markdown", systemImage: "doc.plaintext")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showClearInactiveConfirmation = true
                        } label: {
                            Label("Clear Inactive Sessions", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Clear inactive sessions?",
                isPresented: $showClearInactiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Inactive Sessions", role: .destructive) {
                    clearInactiveSessions()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all closed sessions and their history.")
            }
            .fileExporter(
                isPresented: Binding(
                    get: { exportDocument != nil },
                    set: { if !$0 { exportDocument = nil } }
                ),
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let error) = result {
                    exportErrorMessage = error.localizedDescription
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
        }
    }

    private func reopenSession(_ session: Session) {
        sessionManager.reopenSession(session)
        // Show a confirmation
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func deleteInactiveSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = inactiveSessions[index]
            sessionManager.deleteSession(session)
        }
    }

    private func clearInactiveSessions() {
        for session in inactiveSessions {
            sessionManager.deleteSession(session)
        }
    }

    private func exportAllSessions(format: MathCLIExportFormat) {
        do {
            switch format {
            case .json:
                exportDocument = try makeMathCLIJSONDocument(from: allSessions)
                exportFilename = "MathCLI-Sessions.json"
                exportContentType = .json
            case .markdown:
                exportDocument = makeMathCLIMarkdownDocument(from: allSessions)
                exportFilename = "MathCLI-Sessions.md"
                exportContentType = .plainText
            }
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session
    let isActive: Bool
    let onTap: () -> Void
    let onReopen: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .accessibilityIdentifier("SessionRow_\(session.name)")

                        if isActive {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                        }
                    }

                    Text(session.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(session.entryCount) calculation\(session.entryCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isActive, let onReopen = onReopen {
                    Button {
                        onReopen()
                    } label: {
                        Text("Reopen")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: Session
    @State private var searchText = ""
    @State private var showBookmarksOnly = false
    @State private var exportDocument: MathCLITextDocument?
    @State private var exportFilename = "MathCLI-Session.json"
    @State private var exportContentType: UTType = .json
    @State private var showClearConfirmation = false
    @State private var exportErrorMessage: String?

    var filteredEntries: [HistoryEntry] {
        var entries = session.entries.sorted(by: { $0.timestamp > $1.timestamp })

        if showBookmarksOnly {
            entries = entries.filter { $0.isBookmarked }
        }

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.command.localizedCaseInsensitiveContains(searchText) ||
                entry.result.localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries
    }

    var body: some View {
        List {
            ForEach(filteredEntries) { entry in
                HistoryEntryRow(entry: entry)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleBookmark(entry)
                        } label: {
                            Label(
                                entry.isBookmarked ? "Remove Bookmark" : "Bookmark",
                                systemImage: entry.isBookmarked ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            copyToClipboard(entry)
                        } label: {
                            Label("Copy Calculation", systemImage: "doc.on.doc")
                        }

                        Button {
                            copyResultToClipboard(entry)
                        } label: {
                            Label("Copy Result", systemImage: "number")
                        }
                    }
            }

            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Calculations" : "No Results",
                    systemImage: searchText.isEmpty ? "function" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "This session has no calculations yet" : "Try a different search term")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search calculations")
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showBookmarksOnly.toggle()
                    } label: {
                        Label(
                            showBookmarksOnly ? "Show All" : "Show Bookmarks",
                            systemImage: showBookmarksOnly ? "list.bullet" : "bookmark"
                        )
                    }

                    Divider()

                    Button {
                        exportSession(format: .json)
                    } label: {
                        Label("Export Session as JSON", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        exportSession(format: .markdown)
                    } label: {
                        Label("Export Session as Markdown", systemImage: "doc.plaintext")
                    }

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear Session History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Clear session history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Session History", role: .destructive) {
                clearSessionHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every calculation in \(session.name).")
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private func deleteEntry(_ entry: HistoryEntry) {
        modelContext.delete(entry)
    }

    private func toggleBookmark(_ entry: HistoryEntry) {
        entry.isBookmarked.toggle()
    }

    private func clearSessionHistory() {
        for entry in session.entries {
            modelContext.delete(entry)
        }
    }

    private func exportSession(format: MathCLIExportFormat) {
        do {
            let safeName = session.name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            switch format {
            case .json:
                exportDocument = try makeMathCLIJSONDocument(from: [session])
                exportFilename = "\(safeName).json"
                exportContentType = .json
            case .markdown:
                exportDocument = makeMathCLIMarkdownDocument(from: [session])
                exportFilename = "\(safeName).md"
                exportContentType = .plainText
            }
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func copyToClipboard(_ entry: HistoryEntry) {
        UIPasteboard.general.string = entry.command
    }

    private func copyResultToClipboard(_ entry: HistoryEntry) {
        UIPasteboard.general.string = entry.result
    }
}

struct HistoryEntryRow: View {
    @Environment(\.mathCLITheme) private var appTheme
    @AppStorage("calculatorTextFont") private var calculatorTextFont = MathCLITextFont.monospaced.rawValue
    @AppStorage("calculatorTextColor") private var calculatorTextColor = MathCLITextColor.theme.rawValue

    let entry: HistoryEntry

    private var textFont: MathCLITextFont {
        MathCLITextFont(rawValue: calculatorTextFont) ?? .monospaced
    }

    private var textColor: MathCLITextColor {
        MathCLITextColor(rawValue: calculatorTextColor) ?? .theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if entry.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(appTheme.infoText)
                        .font(.caption)
                }

                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(appTheme.secondaryText)

                Spacer()

                Text(entry.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(appTheme.secondaryText)
            }

            Text(entry.command)
                .font(.system(.body, design: textFont.design))
                .foregroundColor(textColor.color ?? appTheme.commandText)

            Text(entry.result)
                .font(.system(.body, design: textFont.design))
                .foregroundColor(textColor.color ?? appTheme.resultText)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("HistoryEntry_\(entry.command)")
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: HistoryEntry.self, inMemory: true)
}
