//
//  FunctionRegistry.swift
//  MathCLI
//
//  Registry for user-defined functions
//

import Foundation

/// Represents a user-defined function
struct UserFunction: Codable {
    let name: String
    let parameters: [String]
    let body: String
    let help: String?

    init(name: String, parameters: [String], body: String, help: String? = nil) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.help = help
    }
}

/// Manages user-defined functions
class FunctionRegistry {
    static let shared = FunctionRegistry()

    // Current session ID for function scoping
    private var currentSessionId: UUID?
    
    // Session-specific functions (sessionId -> [functionName -> UserFunction])
    private var sessionFunctions: [UUID: [String: UserFunction]] = [:]
    
    // Global functions (available across all sessions)
    private var functions: [String: UserFunction] = [:]
    private let persistenceKey = "MathCLI.UserFunctions"
    private let sessionFunctionsKey = "MathCLI.SessionFunctions"

    private init() {
        loadFunctions()
        loadSessionFunctions()
    }
    
    // MARK: - Session Management
    
    /// Set the current session for function scoping
    func setSession(_ sessionId: UUID) {
        // Save current session functions if we have a session
        if let currentId = currentSessionId {
            saveCurrentSessionFunctions(for: currentId)
        }
        
        // Switch to new session
        currentSessionId = sessionId
        
        // Load functions for the new session
        loadSessionFunctions(for: sessionId)
    }
    
    /// Get the current session ID
    func getCurrentSession() -> UUID? {
        return currentSessionId
    }
    
    /// Clear all functions for the current session
    func clearSessionFunctions() {
        guard let sessionId = currentSessionId else { return }
        sessionFunctions[sessionId] = [:]
        saveSessionFunctions()
    }

    /// Define a new function
    func define(name: String, parameters: [String], body: String, help: String? = nil) {
        let function = UserFunction(name: name, parameters: parameters, body: body, help: help)
        
        if let sessionId = currentSessionId {
            // Define in current session
            if sessionFunctions[sessionId] == nil {
                sessionFunctions[sessionId] = [:]
            }
            sessionFunctions[sessionId]![name] = function
            saveSessionFunctions()
        } else {
            // Define globally if no session
            functions[name] = function
            saveFunctions()
        }
    }

    /// Get a function by name
    func getFunction(name: String) -> UserFunction? {
        // First check current session
        if let sessionId = currentSessionId,
           let sessionFunction = sessionFunctions[sessionId]?[name] {
            return sessionFunction
        }
        
        // Then check global functions
        return functions[name]
    }

    /// Remove a function
    func undefine(name: String) {
        // First try to remove from current session
        if let sessionId = currentSessionId,
           sessionFunctions[sessionId]?.removeValue(forKey: name) != nil {
            saveSessionFunctions()
        }
        
        // Also try to remove from global functions
        if functions.removeValue(forKey: name) != nil {
            saveFunctions()
        }
    }

    /// Get all function names
    func getAllFunctionNames() -> [String] {
        var allNames = Set(functions.keys)
        
        // Add session function names
        if let sessionId = currentSessionId,
           let sessionFuncs = sessionFunctions[sessionId] {
            allNames.formUnion(sessionFuncs.keys)
        }
        
        return Array(allNames).sorted()
    }

    /// Get all functions
    func getAllFunctions() -> [UserFunction] {
        var allFunctions: [String: UserFunction] = functions
        
        // Add session functions (they override global ones with same name)
        if let sessionId = currentSessionId,
           let sessionFuncs = sessionFunctions[sessionId] {
            for (name, function) in sessionFuncs {
                allFunctions[name] = function
            }
        }
        
        return Array(allFunctions.values).sorted { $0.name < $1.name }
    }

    /// Clear all functions
    func clearAll() {
        // Clear session functions
        if let sessionId = currentSessionId {
            sessionFunctions[sessionId] = [:]
            saveSessionFunctions()
        }
        
        // Clear global functions
        functions.removeAll()
        saveFunctions()
    }

    /// Check if a function exists
    func exists(name: String) -> Bool {
        // Check session functions first
        if let sessionId = currentSessionId,
           let sessionFuncs = sessionFunctions[sessionId],
           sessionFuncs[name] != nil {
            return true
        }
        
        // Then check global functions
        return functions[name] != nil
    }

    /// Export functions to dictionary
    func exportFunctions() -> [[String: Any]] {
        let allFunctions = getAllFunctions()
        return allFunctions.map { function in
            var dict: [String: Any] = [
                "name": function.name,
                "parameters": function.parameters,
                "body": function.body
            ]
            if let help = function.help {
                dict["help"] = help
            }
            return dict
        }
    }

    /// Import functions from dictionary
    func importFunctions(_ functionsData: [[String: Any]], merge: Bool = true) {
        if !merge {
            clearAll()
        }

        for funcDict in functionsData {
            guard let name = funcDict["name"] as? String,
                  let parameters = funcDict["parameters"] as? [String],
                  let body = funcDict["body"] as? String else {
                continue
            }

            let help = funcDict["help"] as? String
            define(name: name, parameters: parameters, body: body, help: help)
        }
    }

    // MARK: - Persistence

    private func saveFunctions() {
        let defaults = UserDefaults.standard

        let encoded = functions.values.map { function -> [String: Any] in
            var dict: [String: Any] = [
                "name": function.name,
                "parameters": function.parameters,
                "body": function.body
            ]
            if let help = function.help {
                dict["help"] = help
            }
            return dict
        }

        defaults.set(encoded, forKey: persistenceKey)
    }

    private func loadFunctions() {
        let defaults = UserDefaults.standard

        guard let functionsData = defaults.array(forKey: persistenceKey) as? [[String: Any]] else {
            return
        }

        for funcDict in functionsData {
            guard let name = funcDict["name"] as? String,
                  let parameters = funcDict["parameters"] as? [String],
                  let body = funcDict["body"] as? String else {
                continue
            }

            let help = funcDict["help"] as? String
            let function = UserFunction(name: name, parameters: parameters, body: body, help: help)
            functions[name] = function
        }
    }
    
    // MARK: - Session Persistence
    
    private func saveSessionFunctions() {
        let defaults = UserDefaults.standard
        
        // Convert to a serializable format
        var sessionData: [String: [[String: Any]]] = [:]
        
        for (sessionId, functions) in sessionFunctions {
            let functionsData = functions.values.map { function -> [String: Any] in
                var dict: [String: Any] = [
                    "name": function.name,
                    "parameters": function.parameters,
                    "body": function.body
                ]
                if let help = function.help {
                    dict["help"] = help
                }
                return dict
            }
            sessionData[sessionId.uuidString] = functionsData
        }
        
        defaults.set(sessionData, forKey: sessionFunctionsKey)
    }
    
    private func loadSessionFunctions() {
        let defaults = UserDefaults.standard
        
        guard let sessionData = defaults.object(forKey: sessionFunctionsKey) as? [String: [[String: Any]]] else {
            return
        }
        
        for (sessionIdString, functionsData) in sessionData {
            guard let sessionId = UUID(uuidString: sessionIdString) else { continue }
            
            var functions: [String: UserFunction] = [:]
            
            for funcDict in functionsData {
                guard let name = funcDict["name"] as? String,
                      let parameters = funcDict["parameters"] as? [String],
                      let body = funcDict["body"] as? String else {
                    continue
                }
                
                let help = funcDict["help"] as? String
                let function = UserFunction(name: name, parameters: parameters, body: body, help: help)
                functions[name] = function
            }
            
            sessionFunctions[sessionId] = functions
        }
    }
    
    private func saveCurrentSessionFunctions(for sessionId: UUID) {
        // This is called when switching sessions to save current state
        saveSessionFunctions()
    }
    
    private func loadSessionFunctions(for sessionId: UUID) {
        // Session functions are loaded in loadSessionFunctions()
        // This method exists for consistency with the interface
    }
}
