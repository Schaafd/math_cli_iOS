//
//  OperationExecutor.swift
//  MathCLI
//
//  Executes mathematical operations with variable substitution
//

import Foundation

/// Executes operations and manages the calculation context
class OperationExecutor {
    private let registry: OperationRegistry
    private let variableStore: VariableStore
    private let functionRegistry: FunctionRegistry

    var lastResult: OperationResult = .void

    init(registry: OperationRegistry = .shared,
         variableStore: VariableStore = .shared,
         functionRegistry: FunctionRegistry = .shared) {
        self.registry = registry
        self.variableStore = variableStore
        self.functionRegistry = functionRegistry
    }

    /// Execute a command string
    /// - Parameter command: The command to execute (e.g., "add 5 10" or "multiply $x $y")
    /// - Returns: Result of the execution
    /// - Throws: OperationError if execution fails
    func execute(command: String) throws -> OperationResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .void
        }

        if let assignment = try executeExpressionAssignment(trimmed) {
            storeLastResult(assignment)
            return assignment
        }

        // Check for chain operations (separated by |)
        if trimmed.contains("|") {
            return try executeChain(trimmed)
        }

        if looksLikeExpression(trimmed) {
            let result = try evaluateExpression(trimmed)
            storeLastResult(result)
            return result
        }

        // Parse command into components
        let components = parseCommand(trimmed)
        guard !components.isEmpty else {
            return .void
        }

        let operationName = components[0]
        var args = Array(components.dropFirst())

        // Substitute variables and special references
        args = try substituteVariables(args)

        // Check if it's a user-defined function
        if let userFunction = functionRegistry.getFunction(name: operationName) {
            return try executeUserFunction(userFunction, args: args)
        }

        // Get the operation from registry
        guard let operation = registry.getOperation(name: operationName) else {
            throw OperationError.operationNotFound(operationName)
        }

        // Validate argument count (skip for variadic operations)
        if !operation.isVariadic && args.count != operation.arguments.count {
            throw OperationError.invalidArgumentCount(
                expected: operation.arguments.count,
                got: args.count
            )
        }

        // Execute the operation
        let result = try operation.execute(args: args)

        storeLastResult(result)

        return result
    }

    /// Execute a chain of operations (e.g., "add 5 10 | multiply 2 | sqrt")
    private func executeChain(_ command: String) throws -> OperationResult {
        let operations = command.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var result: OperationResult = .void

        for (index, operation) in operations.enumerated() {
            if index == 0 {
                // First operation executes normally
                result = try execute(command: operation)
            } else {
                // Subsequent operations use previous result as first argument
                let components = parseCommand(operation)
                guard !components.isEmpty else { continue }

                let operationName = components[0]
                var args = Array(components.dropFirst())

                // Prepend the previous result
                args.insert(resultToString(result), at: 0)

                // Execute with substitution
                args = try substituteVariables(args)

                guard let op = registry.getOperation(name: operationName) else {
                    throw OperationError.operationNotFound(operationName)
                }

                result = try op.execute(args: args)
            }
        }

        // Store the final result in session-scoped VariableStore
        storeLastResult(result)

        return result
    }

    private func storeLastResult(_ result: OperationResult) {
        lastResult = result
        variableStore.set(name: "ans", value: result)
        variableStore.set(name: "$", value: result)
    }

    private func executeExpressionAssignment(_ command: String) throws -> OperationResult? {
        let components = parseCommand(command)
        if components.count >= 3, components[0] == "set" {
            let name = components[1]
            let expression = command
                .dropFirst(3)
                .trimmingCharacters(in: .whitespaces)
                .dropFirst(name.count)
                .trimmingCharacters(in: .whitespaces)

            guard isValidVariableName(name), !expression.isEmpty else {
                return nil
            }

            let result = try evaluateExpression(expression)
            variableStore.set(name: name, value: result)
            return result
        }

        guard let equalsIndex = command.firstIndex(of: "=") else {
            return nil
        }

        let name = command[..<equalsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let expression = command[command.index(after: equalsIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidVariableName(name), !expression.isEmpty else {
            return nil
        }

        let result = try evaluateExpression(expression)
        variableStore.set(name: name, value: result)
        return result
    }

    private func isValidVariableName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else {
            return false
        }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func looksLikeExpression(_ command: String) -> Bool {
        if Double(command) != nil {
            return true
        }

        if variableStore.exists(name: command) || command == "$" || command == "ans" {
            return true
        }

        return command.contains { char in
            "+-*/^()%!,".contains(char)
        }
    }

    private func evaluateExpression(_ expression: String) throws -> OperationResult {
        let parser = ExpressionParser(
            expression: expression,
            variableResolver: { [weak self] name in
                try self?.resolveExpressionVariable(name) ?? 0
            },
            functionResolver: { [weak self] name, args in
                guard let self else {
                    throw OperationError.executionError("Expression evaluator is unavailable")
                }
                return try self.resolveExpressionFunction(name: name, args: args)
            }
        )
        return .number(try parser.parse())
    }

    private func resolveExpressionVariable(_ name: String) throws -> Double {
        let lookupName: String
        if name == "$" {
            lookupName = "$"
        } else if name.hasPrefix("$") {
            lookupName = String(name.dropFirst())
        } else {
            lookupName = name
        }

        if lookupName.lowercased() == "pi" || lookupName == "π" {
            return Double.pi
        }
        if lookupName.lowercased() == "e" {
            return Darwin.M_E
        }
        if lookupName.lowercased() == "tau" {
            return 2 * Double.pi
        }

        guard let value = variableStore.get(name: lookupName) else {
            throw OperationError.variableNotFound(lookupName)
        }

        switch value {
        case .number(let number):
            return number
        case .integer(let integer):
            return Double(integer)
        case .boolean(let bool):
            return bool ? 1 : 0
        default:
            throw OperationError.invalidArgumentType(
                argument: lookupName,
                expected: "numeric variable",
                got: value.description
            )
        }
    }

    private func resolveExpressionFunction(name: String, args: [Double]) throws -> Double {
        let normalizedName = name.lowercased()

        switch normalizedName {
        case "sin": return sin(try requireUnary(args, name))
        case "cos": return cos(try requireUnary(args, name))
        case "tan": return tan(try requireUnary(args, name))
        case "asin", "arcsin": return asin(try requireUnary(args, name))
        case "acos", "arccos": return acos(try requireUnary(args, name))
        case "atan", "arctan": return atan(try requireUnary(args, name))
        case "sinh": return sinh(try requireUnary(args, name))
        case "cosh": return cosh(try requireUnary(args, name))
        case "tanh": return tanh(try requireUnary(args, name))
        case "asinh": return asinh(try requireUnary(args, name))
        case "acosh": return acosh(try requireUnary(args, name))
        case "atanh": return atanh(try requireUnary(args, name))
        case "sqrt": return sqrt(try requireUnary(args, name))
        case "cbrt": return cbrt(try requireUnary(args, name))
        case "abs": return abs(try requireUnary(args, name))
        case "ln": return log(try requireUnary(args, name))
        case "log", "log10": return log10(try requireUnary(args, name))
        case "exp": return exp(try requireUnary(args, name))
        case "floor": return floor(try requireUnary(args, name))
        case "ceil": return ceil(try requireUnary(args, name))
        case "round": return round(try requireUnary(args, name))
        case "trunc": return trunc(try requireUnary(args, name))
        case "to_radians", "radians": return try requireUnary(args, name) * Double.pi / 180
        case "to_degrees", "degrees": return try requireUnary(args, name) * 180 / Double.pi
        case "pow", "power":
            guard args.count == 2 else {
                throw OperationError.invalidArgumentCount(expected: 2, got: args.count)
            }
            return pow(args[0], args[1])
        case "atan2":
            guard args.count == 2 else {
                throw OperationError.invalidArgumentCount(expected: 2, got: args.count)
            }
            return atan2(args[0], args[1])
        case "min":
            guard !args.isEmpty else {
                throw OperationError.invalidValue("min requires at least one value")
            }
            return args.min()!
        case "max":
            guard !args.isEmpty else {
                throw OperationError.invalidValue("max requires at least one value")
            }
            return args.max()!
        case "mean", "avg", "average":
            guard !args.isEmpty else {
                throw OperationError.invalidValue("mean requires at least one value")
            }
            return args.reduce(0, +) / Double(args.count)
        default:
            return try executeExpressionBackedFunction(name: name, args: args)
        }
    }

    private func requireUnary(_ args: [Double], _ name: String) throws -> Double {
        guard args.count == 1 else {
            throw OperationError.invalidArgumentCount(expected: 1, got: args.count)
        }
        return args[0]
    }

    private func executeExpressionBackedFunction(name: String, args: [Double]) throws -> Double {
        let stringArgs = args.map { resultToString(.number($0)) }

        if let userFunction = functionRegistry.getFunction(name: name) {
            let result = try executeUserFunction(userFunction, args: stringArgs)
            return try numericResult(result, functionName: name)
        }

        guard let operation = registry.getOperation(name: name) else {
            throw OperationError.operationNotFound(name)
        }

        if !operation.isVariadic && args.count != operation.arguments.count {
            throw OperationError.invalidArgumentCount(expected: operation.arguments.count, got: args.count)
        }

        let result = try operation.execute(args: args.map { $0 as Any })
        return try numericResult(result, functionName: name)
    }

    private func numericResult(_ result: OperationResult, functionName: String) throws -> Double {
        switch result {
        case .number(let number):
            return number
        case .integer(let integer):
            return Double(integer)
        case .boolean(let bool):
            return bool ? 1 : 0
        default:
            throw OperationError.invalidArgumentType(
                argument: functionName,
                expected: "numeric function result",
                got: result.description
            )
        }
    }

    /// Parse command string into components, respecting quotes
    private func parseCommand(_ command: String) -> [String] {
        var components: [String] = []
        var current = ""
        var inQuotes = false

        for char in command {
            if char == "\"" {
                inQuotes.toggle()
            } else if char.isWhitespace && !inQuotes {
                if !current.isEmpty {
                    components.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            components.append(current)
        }

        return components
    }

    /// Substitute variable references in arguments
    private func substituteVariables(_ args: [String]) throws -> [String] {
        return try args.map { arg in
            // Check for variable reference
            if arg.hasPrefix("$") {
                let varName = String(arg.dropFirst())

                // Handle $ by treating it as the variable named "$"
                // This ensures it's session-scoped through VariableStore
                let lookupName = varName.isEmpty ? "$" : varName

                // Get from variable store (which is session-scoped)
                guard let value = variableStore.get(name: lookupName) else {
                    throw OperationError.variableNotFound(lookupName)
                }

                return resultToString(value)
            }

            return arg
        }
    }

    /// Convert OperationResult to String for argument passing
    private func resultToString(_ result: OperationResult) -> String {
        switch result {
        case .number(let value):
            return "\(value)"
        case .integer(let value):
            return "\(value)"
        case .string(let value):
            return value
        case .boolean(let value):
            return value ? "true" : "false"
        case .array(let values):
            return values.map { "\($0)" }.joined(separator: ",")
        default:
            return result.description
        }
    }

    /// Execute a user-defined function
    private func executeUserFunction(_ function: UserFunction, args: [String]) throws -> OperationResult {
        guard args.count == function.parameters.count else {
            throw OperationError.invalidArgumentCount(
                expected: function.parameters.count,
                got: args.count
            )
        }

        // Create new scope
        variableStore.pushScope()

        // Bind parameters to arguments
        for (param, arg) in zip(function.parameters, args) {
            // Try to parse as number, otherwise store as string
            if let numValue = Double(arg) {
                variableStore.set(name: param, value: .number(numValue))
            } else {
                variableStore.set(name: param, value: .string(arg))
            }
        }

        // Execute function body
        let result: OperationResult
        do {
            result = try execute(command: function.body)
        } catch {
            variableStore.popScope()
            throw error
        }

        // Pop scope
        variableStore.popScope()

        return result
    }
}

private final class ExpressionParser {
    private enum Token: Equatable {
        case number(Double)
        case identifier(String)
        case plus
        case minus
        case multiply
        case divide
        case modulo
        case power
        case factorial
        case leftParen
        case rightParen
        case comma
        case end
    }

    private let tokens: [Token]
    private let variableResolver: (String) throws -> Double
    private let functionResolver: (String, [Double]) throws -> Double
    private var index = 0

    init(
        expression: String,
        variableResolver: @escaping (String) throws -> Double,
        functionResolver: @escaping (String, [Double]) throws -> Double
    ) {
        self.tokens = ExpressionParser.tokenize(expression)
        self.variableResolver = variableResolver
        self.functionResolver = functionResolver
    }

    func parse() throws -> Double {
        let value = try parseAdditive()
        guard current == .end else {
            throw OperationError.parsingError("Unexpected token near '\(current)'")
        }
        guard value.isFinite else {
            throw OperationError.invalidValue("Expression result must be finite")
        }
        return value
    }

    private static func tokenize(_ expression: String) -> [Token] {
        var tokens: [Token] = []
        var index = expression.startIndex

        while index < expression.endIndex {
            let char = expression[index]

            if char.isWhitespace {
                index = expression.index(after: index)
                continue
            }

            if char.isNumber || char == "." {
                let start = index
                var hasExponent = false
                index = expression.index(after: index)

                while index < expression.endIndex {
                    let next = expression[index]
                    if next.isNumber || next == "." {
                        index = expression.index(after: index)
                    } else if (next == "e" || next == "E") && !hasExponent {
                        hasExponent = true
                        index = expression.index(after: index)
                        if index < expression.endIndex, (expression[index] == "+" || expression[index] == "-") {
                            index = expression.index(after: index)
                        }
                    } else {
                        break
                    }
                }

                let text = String(expression[start..<index])
                tokens.append(.number(Double(text) ?? .nan))
                continue
            }

            if char.isLetter || char == "_" || char == "$" || char == "π" {
                let start = index
                index = expression.index(after: index)
                while index < expression.endIndex {
                    let next = expression[index]
                    if next.isLetter || next.isNumber || next == "_" {
                        index = expression.index(after: index)
                    } else {
                        break
                    }
                }
                tokens.append(.identifier(String(expression[start..<index])))
                continue
            }

            switch char {
            case "+": tokens.append(.plus)
            case "-": tokens.append(.minus)
            case "*", "×": tokens.append(.multiply)
            case "/", "÷": tokens.append(.divide)
            case "%": tokens.append(.modulo)
            case "^": tokens.append(.power)
            case "!": tokens.append(.factorial)
            case "(": tokens.append(.leftParen)
            case ")": tokens.append(.rightParen)
            case ",": tokens.append(.comma)
            default:
                tokens.append(.identifier(String(char)))
            }
            index = expression.index(after: index)
        }

        tokens.append(.end)
        return tokens
    }

    private var current: Token {
        tokens[index]
    }

    @discardableResult
    private func consume(_ token: Token) -> Bool {
        guard current == token else {
            return false
        }
        index += 1
        return true
    }

    private func parseAdditive() throws -> Double {
        var value = try parseMultiplicative()

        while true {
            if consume(.plus) {
                value += try parseMultiplicative()
            } else if consume(.minus) {
                value -= try parseMultiplicative()
            } else {
                return value
            }
        }
    }

    private func parseMultiplicative() throws -> Double {
        var value = try parseUnary()

        while true {
            if consume(.multiply) {
                value *= try parseUnary()
            } else if consume(.divide) {
                let divisor = try parseUnary()
                guard divisor != 0 else {
                    throw OperationError.divisionByZero
                }
                value /= divisor
            } else if consume(.modulo) {
                let divisor = try parseUnary()
                guard divisor != 0 else {
                    throw OperationError.divisionByZero
                }
                value.formTruncatingRemainder(dividingBy: divisor)
            } else {
                return value
            }
        }
    }

    private func parsePower() throws -> Double {
        let base = try parsePostfix()
        if consume(.power) {
            return pow(base, try parseUnary())
        }
        return base
    }

    private func parseUnary() throws -> Double {
        if consume(.plus) {
            return try parseUnary()
        }
        if consume(.minus) {
            let value = try parseUnary()
            return -value
        }
        return try parsePower()
    }

    private func parsePostfix() throws -> Double {
        var value = try parsePrimary()

        while consume(.factorial) {
            guard value >= 0, value.rounded() == value else {
                throw OperationError.invalidValue("Factorial requires a non-negative integer")
            }
            guard value <= 20 else {
                throw OperationError.invalidValue("Factorial input too large (max 20)")
            }
            value = factorial(Int(value))
        }

        return value
    }

    private func parsePrimary() throws -> Double {
        switch current {
        case .number(let value):
            index += 1
            guard value.isFinite else {
                throw OperationError.invalidValue("Invalid number")
            }
            return value

        case .identifier(let name):
            index += 1
            if consume(.leftParen) {
                let args = try parseFunctionArguments()
                return try functionResolver(name, args)
            }
            return try variableResolver(name)

        case .leftParen:
            index += 1
            let value = try parseAdditive()
            guard consume(.rightParen) else {
                throw OperationError.parsingError("Missing closing parenthesis")
            }
            return value

        default:
            throw OperationError.parsingError("Expected number, variable, or function")
        }
    }

    private func parseFunctionArguments() throws -> [Double] {
        if consume(.rightParen) {
            return []
        }

        var args: [Double] = []
        while true {
            args.append(try parseAdditive())
            if consume(.comma) {
                continue
            }
            guard consume(.rightParen) else {
                throw OperationError.parsingError("Missing closing parenthesis")
            }
            return args
        }
    }

    private func factorial(_ value: Int) -> Double {
        guard value > 1 else {
            return 1
        }
        return Double((2...value).reduce(1, *))
    }
}
