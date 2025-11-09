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

    // Current session ID for scoping functions
    private var currentSessionId: UUID?

    private var functions: [String: UserFunction] = [:]
    private let persistenceKey = "MathCLI.UserFunctions"

    private init() {
        // Functions will be loaded when session is set
    }

    /// Set the current session and load its functions
    func setSession(_ sessionId: UUID?) {
        // Save current session's functions before switching
        if let currentId = currentSessionId {
            saveSessionFunctions(for: currentId)
        }

        // Switch to new session
        currentSessionId = sessionId

        // Load new session's functions
        if let sessionId = sessionId {
            loadSessionFunctions(for: sessionId)
        } else {
            functions = [:]
        }
    }

    /// Define a new function
    func define(name: String, parameters: [String], body: String, help: String? = nil) {
        let function = UserFunction(name: name, parameters: parameters, body: body, help: help)
        functions[name] = function
        saveFunctions()
    }

    /// Get a function by name
    func getFunction(name: String) -> UserFunction? {
        return functions[name]
    }

    /// Remove a function
    func undefine(name: String) {
        functions.removeValue(forKey: name)
        saveFunctions()
    }

    /// Get all function names
    func getAllFunctionNames() -> [String] {
        return Array(functions.keys).sorted()
    }

    /// Get all functions
    func getAllFunctions() -> [UserFunction] {
        return Array(functions.values).sorted { $0.name < $1.name }
    }

    /// Clear all functions
    func clearAll() {
        functions.removeAll()
        saveFunctions()
    }

    /// Check if a function exists
    func exists(name: String) -> Bool {
        return functions[name] != nil
    }

    /// Export functions to dictionary
    func exportFunctions() -> [[String: Any]] {
        return functions.values.map { function in
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

    private func sessionPersistenceKey(for sessionId: UUID) -> String {
        return "\(persistenceKey).\(sessionId.uuidString)"
    }

    private func saveSessionFunctions(for sessionId: UUID) {
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

        defaults.set(encoded, forKey: sessionPersistenceKey(for: sessionId))
    }

    private func loadSessionFunctions(for sessionId: UUID) {
        let defaults = UserDefaults.standard
        functions = [:]

        guard let functionsData = defaults.array(forKey: sessionPersistenceKey(for: sessionId)) as? [[String: Any]] else {
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

    private func saveFunctions() {
        guard let sessionId = currentSessionId else { return }
        saveSessionFunctions(for: sessionId)
    }

    private func loadFunctions() {
        guard let sessionId = currentSessionId else { return }
        loadSessionFunctions(for: sessionId)
    }
}
