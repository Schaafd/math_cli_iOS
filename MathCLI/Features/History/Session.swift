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
        // Deactivate current session
        if let current = currentSession {
            current.isActive = false
        }

        // Activate selected session
        session.isActive = true
        currentSession = session

        do {
            try modelContext.save()
            loadSessions() // Refresh the sessions array
        } catch {
            print("Failed to switch session: \(error)")
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