//
//  Session.swift
//  MathCLI
//
//  SwiftData model for calculation sessions
//

import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var isActive: Bool
    @Relationship(deleteRule: .cascade, inverse: \HistoryEntry.session)
    var entries: [HistoryEntry] = []

    init(name: String, createdAt: Date = Date(), isActive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.isActive = isActive
    }

    var entryCount: Int {
        return entries.count
    }
}

// MARK: - Session Manager

@MainActor
@Observable
class SessionManager {
    var currentSession: Session?
    var sessions: [Session] = []
    private let modelContext: ModelContext

    // Computed property to match CalculatorView expectations
    var activeSession: Session? {
        return currentSession
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSessions()
        loadCurrentSession()

        // Ensure there's always an initial active session
        if currentSession == nil {
            print("🔍 SessionManager init: No active session found, creating initial session")
            let _ = createNewSession(name: "Session \(Date().formatted(date: .abbreviated, time: .shortened))")
        }
    }

    func createSession(name: String? = nil) -> Session {
        return createNewSession(name: name)
    }

    func createNewSession(name: String? = nil) -> Session {
        // Close any existing active session
        if let current = currentSession {
            current.isActive = false
        }

        let sessionName = name ?? "Session \(Date().formatted(date: .abbreviated, time: .shortened))"
        let session = Session(name: sessionName, isActive: true)
        
        modelContext.insert(session)
        currentSession = session
        
        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to save new session: \(error)")
        }
        
        return session
    }

    func switchToSession(_ session: Session) {
        // Just switch the current session without deactivating others
        // This allows multiple sessions to remain active (open in tabs)
        currentSession = session

        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to switch session: \(error)")
        }
    }

    func reopenSession(_ session: Session) {
        // Activate the session without deactivating others
        session.isActive = true

        // Switch to this session
        currentSession = session

        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to reopen session: \(error)")
        }
    }

    func closeSession(_ session: Session) {
        // Don't allow closing the last active session
        let activeSessions = sessions.filter { $0.isActive }
        guard activeSessions.count > 1 || !session.isActive else {
            print("Cannot close the last active session")
            return
        }

        // Mark session as inactive (close the tab)
        session.isActive = false

        // If closing the current session, switch to another active one
        if currentSession?.id == session.id {
            if let nextSession = sessions.first(where: { $0.isActive && $0.id != session.id }) {
                currentSession = nextSession
            } else {
                currentSession = nil
            }
        }

        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to close session: \(error)")
        }
    }

    func deleteSession(_ session: Session) {
        // If deleting the current session, set current to nil
        if currentSession?.id == session.id {
            currentSession = nil
        }

        modelContext.delete(session)

        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to delete session: \(error)")
        }
    }

    func renameSession(_ session: Session, newName: String) {
        session.name = newName
        
        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to rename session: \(error)")
        }
    }

    func closeCurrentSession() {
        currentSession?.isActive = false
        currentSession = nil
        
        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to close session: \(error)")
        }
    }

    private func loadSessions() {
        do {
            let descriptor = FetchDescriptor<Session>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            sessions = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load sessions: \(error)")
            sessions = []
        }
    }

    private func loadCurrentSession() {
        do {
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { session in
                    session.isActive == true
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let activeSessions = try modelContext.fetch(descriptor)
            currentSession = activeSessions.first
        } catch {
            print("Failed to load current session: \(error)")
        }
    }

    func ensureActiveSession() -> Session {
        if let current = currentSession, current.isActive {
            return current
        } else {
            return createNewSession()
        }
    }
}