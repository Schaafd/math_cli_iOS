//
//  VariableStore.swift
//  MathCLI
//
//  Variable storage with scoping and persistence support
//

import Foundation

/// Manages variables with scoping and persistence
class VariableStore {
    static let shared = VariableStore()

    // Current session ID for variable scoping
    private var currentSessionId: UUID?
    
    // Session-specific variables (sessionId -> [variableName -> value])
    private var sessionVariables: [UUID: [String: OperationResult]] = [:]
    
    // Stack of scopes for the current session (each scope is a dictionary of variables)
    private var scopes: [[String: OperationResult]] = [[:]]

    // Persistent variables (saved across sessions)
    private var persistentVariables: [String: OperationResult] = [:]

    // Set of variable names that should be persisted
    private var persistentKeys: Set<String> = []

    private let persistenceKey = "MathCLI.PersistentVariables"
    private let persistenceKeysKey = "MathCLI.PersistentKeys"
    private let sessionVariablesKey = "MathCLI.SessionVariables"

    private init() {
        loadPersistentVariables()
        loadSessionVariables()
    }
    
    // MARK: - Session Management
    
    /// Set the current session for variable scoping
    func setSession(_ sessionId: UUID) {
        // Save current session variables if we have a session
        if let currentId = currentSessionId {
            saveCurrentSessionVariables(for: currentId)
        }
        
        // Switch to new session
        currentSessionId = sessionId
        
        // Load variables for the new session
        loadSessionVariables(for: sessionId)
    }
    
    /// Get the current session ID
    func getCurrentSession() -> UUID? {
        return currentSessionId
    }
    
    /// Clear all variables for the current session
    func clearSessionVariables() {
        guard let sessionId = currentSessionId else { return }
        sessionVariables[sessionId] = [:]
        scopes = [[:]]
        saveSessionVariables()
    }

    /// Set a variable in the current scope
    func set(name: String, value: OperationResult, persist: Bool = false) {
        guard !scopes.isEmpty else {
            scopes.append([name: value])
            return
        }

        scopes[scopes.count - 1][name] = value
        
        // Also save to session variables if we have a current session
        if let sessionId = currentSessionId {
            if sessionVariables[sessionId] == nil {
                sessionVariables[sessionId] = [:]
            }
            sessionVariables[sessionId]![name] = value
            saveSessionVariables()
        }

        if persist {
            persistentKeys.insert(name)
            persistentVariables[name] = value
            savePersistentVariables()
        }
    }

    /// Get a variable value (searches from current scope upwards)
    func get(name: String) -> OperationResult? {
        // Search in scopes from innermost to outermost
        for scope in scopes.reversed() {
            if let value = scope[name] {
                return value
            }
        }

        // Check persistent variables
        return persistentVariables[name]
    }

    /// Remove a variable from current scope
    func unset(name: String) {
        guard !scopes.isEmpty else { return }
        scopes[scopes.count - 1].removeValue(forKey: name)
        
        // Also remove from session variables
        if let sessionId = currentSessionId {
            sessionVariables[sessionId]?.removeValue(forKey: name)
            saveSessionVariables()
        }

        // Also remove from persistent if it exists
        if persistentKeys.contains(name) {
            persistentKeys.remove(name)
            persistentVariables.removeValue(forKey: name)
            savePersistentVariables()
        }
    }

    /// Get all variables in current scope
    func getAllVariables() -> [String: OperationResult] {
        var allVars: [String: OperationResult] = [:]

        // Merge all scopes (outer scopes first, then override with inner)
        for scope in scopes {
            allVars.merge(scope) { _, new in new }
        }

        // Add persistent variables
        allVars.merge(persistentVariables) { _, new in new }

        return allVars
    }

    /// Get all variable names
    func getAllVariableNames() -> [String] {
        return Array(getAllVariables().keys).sorted()
    }

    /// Clear all variables in current scope
    func clearCurrentScope() {
        guard !scopes.isEmpty else { return }
        scopes[scopes.count - 1].removeAll()
    }

    /// Clear all variables including persistent
    func clearAll() {
        scopes = [[:]]
        persistentVariables.removeAll()
        persistentKeys.removeAll()
        savePersistentVariables()
    }

    /// Push a new scope onto the stack
    func pushScope() {
        scopes.append([:])
    }

    /// Pop the current scope from the stack
    func popScope() {
        guard scopes.count > 1 else { return }
        scopes.removeLast()
    }

    /// Make a variable persistent
    func persist(name: String) {
        guard let value = get(name: name) else { return }
        persistentKeys.insert(name)
        persistentVariables[name] = value
        savePersistentVariables()
    }

    /// Get persistent variable names
    func getPersistentVariableNames() -> [String] {
        return Array(persistentKeys).sorted()
    }

    /// Check if a variable exists
    func exists(name: String) -> Bool {
        return get(name: name) != nil
    }

    /// Export all variables to dictionary
    func exportVariables() -> [String: String] {
        let allVars = getAllVariables()
        var exported: [String: String] = [:]

        for (key, value) in allVars {
            exported[key] = value.description
        }

        return exported
    }

    /// Import variables from dictionary
    func importVariables(_ variables: [String: String], merge: Bool = true) {
        if !merge {
            clearAll()
        }

        for (key, valueStr) in variables {
            // Try to parse as number
            if let numValue = Double(valueStr) {
                set(name: key, value: .number(numValue))
            } else if valueStr == "true" {
                set(name: key, value: .boolean(true))
            } else if valueStr == "false" {
                set(name: key, value: .boolean(false))
            } else {
                set(name: key, value: .string(valueStr))
            }
        }
    }

    // MARK: - Persistence

    private func savePersistentVariables() {
        let defaults = UserDefaults.standard

        // Save persistent variable values
        var savedVars: [String: String] = [:]
        for (key, value) in persistentVariables {
            savedVars[key] = value.description
        }

        defaults.set(savedVars, forKey: persistenceKey)
        defaults.set(Array(persistentKeys), forKey: persistenceKeysKey)
    }

    private func loadPersistentVariables() {
        let defaults = UserDefaults.standard

        // Load persistent keys
        if let keys = defaults.array(forKey: persistenceKeysKey) as? [String] {
            persistentKeys = Set(keys)
        }

        // Load persistent variables
        if let savedVars = defaults.dictionary(forKey: persistenceKey) as? [String: String] {
            for (key, valueStr) in savedVars {
                if let numValue = Double(valueStr) {
                    persistentVariables[key] = .number(numValue)
                } else if valueStr == "true" {
                    persistentVariables[key] = .boolean(true)
                } else if valueStr == "false" {
                    persistentVariables[key] = .boolean(false)
                } else {
                    persistentVariables[key] = .string(valueStr)
                }
            }
        }
    }
    
    // MARK: - Session Variable Persistence
    
    private func saveSessionVariables() {
        let defaults = UserDefaults.standard
        var sessionData: [String: [String: String]] = [:]
        
        for (sessionId, variables) in sessionVariables {
            var sessionVars: [String: String] = [:]
            for (key, value) in variables {
                sessionVars[key] = value.description
            }
            sessionData[sessionId.uuidString] = sessionVars
        }
        
        defaults.set(sessionData, forKey: sessionVariablesKey)
    }
    
    private func loadSessionVariables() {
        let defaults = UserDefaults.standard
        
        if let sessionData = defaults.dictionary(forKey: sessionVariablesKey) as? [String: [String: String]] {
            for (sessionIdString, variables) in sessionData {
                guard let sessionId = UUID(uuidString: sessionIdString) else { continue }
                
                var sessionVars: [String: OperationResult] = [:]
                for (key, valueStr) in variables {
                    if let numValue = Double(valueStr) {
                        sessionVars[key] = .number(numValue)
                    } else if valueStr == "true" {
                        sessionVars[key] = .boolean(true)
                    } else if valueStr == "false" {
                        sessionVars[key] = .boolean(false)
                    } else {
                        sessionVars[key] = .string(valueStr)
                    }
                }
                sessionVariables[sessionId] = sessionVars
            }
        }
    }
    
    private func saveCurrentSessionVariables(for sessionId: UUID) {
        // Save current scopes into session variables
        var allVars: [String: OperationResult] = [:]
        for scope in scopes {
            allVars.merge(scope) { _, new in new }
        }
        sessionVariables[sessionId] = allVars
        saveSessionVariables()
    }
    
    private func loadSessionVariables(for sessionId: UUID) {
        // Load session variables into scopes
        scopes = [[:]]
        if let sessionVars = sessionVariables[sessionId] {
            scopes = [sessionVars]
        }
    }
}
