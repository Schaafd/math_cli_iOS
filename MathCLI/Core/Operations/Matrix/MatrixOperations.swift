//
//  MatrixOperations.swift
//  MathCLI
//
//  Matrix operations (12 operations)
//  Uses Accelerate framework for performance
//
//  Note: To suppress LAPACK deprecation warnings, compile with:
//  -DACCELERATE_NEW_LAPACK
//

import Foundation
import Accelerate

// Helper to parse matrix from string like "[[1,2],[3,4]]"
private func parseMatrix(_ value: Any) throws -> [[Double]] {
    func validate(_ matrix: [[Double]]) throws -> [[Double]] {
        guard !matrix.isEmpty else {
            throw OperationError.invalidValue("Matrix cannot be empty")
        }
        guard let firstRowCount = matrix.first?.count, firstRowCount > 0 else {
            throw OperationError.invalidValue("Matrix rows cannot be empty")
        }
        guard matrix.allSatisfy({ $0.count == firstRowCount && !$0.isEmpty }) else {
            throw OperationError.matrixDimensionMismatch
        }
        return matrix
    }

    if let matrix = value as? [[Double]] {
        return try validate(matrix)
    } else if let stringValue = value as? String {
        // Parse string representation
        let cleaned = stringValue
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")

        guard !cleaned.isEmpty && cleaned != "[]" else {
            throw OperationError.invalidValue("Matrix cannot be empty")
        }

        let rows = cleaned.components(separatedBy: "],[")
        var matrix: [[Double]] = []

        for row in rows {
            guard !row.isEmpty else {
                throw OperationError.invalidValue("Matrix rows cannot be empty")
            }
            let elements = row.components(separatedBy: ",")
            let doubleElements = try elements.map { element -> Double in
                guard let value = Double(element) else {
                    throw OperationError.invalidValue("Invalid matrix element: \(element)")
                }
                return value
            }
            matrix.append(doubleElements)
        }

        return try validate(matrix)
    } else {
        throw OperationError.invalidArgumentType(
            argument: "matrix",
            expected: "matrix array",
            got: String(describing: value)
        )
    }
}

private func determinantUsingElimination(_ matrix: [[Double]]) throws -> Double {
    var m = matrix
    let n = m.count
    var determinant = 1.0

    for i in 0..<n {
        var pivotRow = i
        for row in (i + 1)..<n {
            if abs(m[row][i]) > abs(m[pivotRow][i]) {
                pivotRow = row
            }
        }

        guard abs(m[pivotRow][i]) > 1e-12 else {
            return 0
        }

        if pivotRow != i {
            m.swapAt(i, pivotRow)
            determinant *= -1
        }

        let pivot = m[i][i]
        determinant *= pivot

        for row in (i + 1)..<n {
            let factor = m[row][i] / pivot
            for col in i..<n {
                m[row][col] -= factor * m[i][col]
            }
        }
    }

    return determinant
}

private func inverseUsingGaussJordan(_ matrix: [[Double]]) throws -> [[Double]] {
    let n = matrix.count
    var augmented = Array(repeating: Array(repeating: 0.0, count: 2 * n), count: n)

    for row in 0..<n {
        for col in 0..<n {
            augmented[row][col] = matrix[row][col]
        }
        augmented[row][n + row] = 1.0
    }

    for pivotIndex in 0..<n {
        var pivotRow = pivotIndex
        for row in pivotIndex..<n {
            if abs(augmented[row][pivotIndex]) > abs(augmented[pivotRow][pivotIndex]) {
                pivotRow = row
            }
        }

        guard abs(augmented[pivotRow][pivotIndex]) > 1e-12 else {
            throw OperationError.singularMatrix
        }

        if pivotRow != pivotIndex {
            augmented.swapAt(pivotIndex, pivotRow)
        }

        let pivot = augmented[pivotIndex][pivotIndex]
        for col in 0..<(2 * n) {
            augmented[pivotIndex][col] /= pivot
        }

        for row in 0..<n where row != pivotIndex {
            let factor = augmented[row][pivotIndex]
            for col in 0..<(2 * n) {
                augmented[row][col] -= factor * augmented[pivotIndex][col]
            }
        }
    }

    return augmented.map { row in
        Array(row[n..<(2 * n)])
    }
}

// MARK: - Determinant

struct DetOperation: MathOperation {
    static var name = "det"
    static var arguments = ["matrix"]
    static var help = "Calculate matrix determinant: det matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        let rows = matrix.count
        let cols = matrix[0].count

        guard rows == cols else {
            throw OperationError.invalidValue("Determinant requires square matrix")
        }

        return .number(try determinantUsingElimination(matrix))
    }
}

// MARK: - Transpose

struct TransposeOperation: MathOperation {
    static var name = "transpose"
    static var arguments = ["matrix"]
    static var help = "Transpose matrix: transpose matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        let rows = matrix.count
        let cols = matrix[0].count

        var transposed = Array(repeating: Array(repeating: 0.0, count: rows), count: cols)

        for i in 0..<rows {
            for j in 0..<cols {
                transposed[j][i] = matrix[i][j]
            }
        }

        return .matrix(transposed)
    }
}

// MARK: - Eigenvalues (simplified - real only)

struct EigenvaluesOperation: MathOperation {
    static var name = "eigenvalues"
    static var arguments = ["matrix"]
    static var help = "Calculate eigenvalues (real): eigenvalues matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        let n = matrix.count
        guard n == matrix[0].count else {
            throw OperationError.invalidValue("Eigenvalues require square matrix")
        }

        var flatMatrix = matrix.flatMap { $0 }
        var eigenvaluesReal = [Double](repeating: 0, count: n)
        var eigenvaluesImag = [Double](repeating: 0, count: n)

        // Calculate eigenvalues using safe buffer pointer access
        let info = flatMatrix.withUnsafeMutableBufferPointer { matrixBuffer in
            eigenvaluesReal.withUnsafeMutableBufferPointer { realBuffer in
                eigenvaluesImag.withUnsafeMutableBufferPointer { imagBuffer in
                    var jobvl: Int8 = 78 // 'N'
                    var jobvr: Int8 = 78 // 'N'
                    var nSize = Int32(n)
                    var lda = Int32(n)
                    var lwork = Int32(4 * n)
                    var work = [Double](repeating: 0, count: Int(lwork))
                    var infoResult: Int32 = 0
                    
                    // Left and right eigenvectors not computed (nil pointers)
                    let vl: UnsafeMutablePointer<Double>? = nil
                    let vr: UnsafeMutablePointer<Double>? = nil
                    var ldvl = Int32(1)
                    var ldvr = Int32(1)
                    
                    dgeev_(&jobvl, &jobvr, &nSize, matrixBuffer.baseAddress!, &lda,
                           realBuffer.baseAddress!, imagBuffer.baseAddress!,
                           vl, &ldvl, vr, &ldvr,
                           &work, &lwork, &infoResult)
                    
                    return infoResult
                }
            }
        }

        guard info == 0 else {
            throw OperationError.executionError("Eigenvalue computation failed")
        }

        // Return only real parts for simplicity
        return .array(eigenvaluesReal)
    }
}

// MARK: - Eigenvectors

struct EigenvectorsOperation: MathOperation {
    static var name = "eigenvectors"
    static var arguments = ["matrix"]
    static var help = "Calculate eigenvectors: eigenvectors matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        let n = matrix.count
        guard n == matrix[0].count else {
            throw OperationError.invalidValue("Eigenvectors require square matrix")
        }

        guard n == 2 else {
            throw OperationError.invalidValue("Eigenvectors support 2x2 real matrices in v1")
        }

        let a = matrix[0][0]
        let b = matrix[0][1]
        let c = matrix[1][0]
        let d = matrix[1][1]
        let trace = a + d
        let determinant = a * d - b * c
        let discriminant = trace * trace - 4 * determinant

        guard discriminant >= 0 else {
            throw OperationError.invalidValue("Eigenvectors require real eigenvalues in v1")
        }

        let root = sqrt(discriminant)
        let eigenvalues = [(trace + root) / 2, (trace - root) / 2]

        let vectors = eigenvalues.map { lambda -> [Double] in
            let x: Double
            let y: Double

            if abs(b) < 1e-12 && abs(c) < 1e-12 {
                return abs(lambda - a) <= abs(lambda - d) ? [1.0, 0.0] : [0.0, 1.0]
            }

            if abs(b) > abs(c) {
                x = b
                y = lambda - a
            } else {
                x = lambda - d
                y = c
            }

            let length = sqrt(x * x + y * y)
            if length < 1e-12 {
                return [1.0, 0.0]
            }
            return [x / length, y / length]
        }

        return .matrix(vectors)
    }
}

// MARK: - Trace

struct TraceOperation: MathOperation {
    static var name = "trace"
    static var arguments = ["matrix"]
    static var help = "Calculate matrix trace (sum of diagonal): trace matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        let n = min(matrix.count, matrix[0].count)
        var trace: Double = 0

        for i in 0..<n {
            trace += matrix[i][i]
        }

        return .number(trace)
    }
}

// MARK: - Rank (simplified)

struct RankOperation: MathOperation {
    static var name = "rank"
    static var arguments = ["matrix"]
    static var help = "Calculate matrix rank: rank matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        // Simplified rank calculation using row reduction
        var m = matrix
        let rows = m.count
        let cols = m[0].count
        var rank = 0

        for col in 0..<min(rows, cols) {
            // Find pivot
            var pivotRow = col
            for row in (col + 1)..<rows {
                if abs(m[row][col]) > abs(m[pivotRow][col]) {
                    pivotRow = row
                }
            }

            if abs(m[pivotRow][col]) < 1e-10 {
                continue
            }

            // Swap rows
            if pivotRow != col {
                m.swapAt(col, pivotRow)
            }

            rank += 1

            // Eliminate
            for row in (col + 1)..<rows {
                let factor = m[row][col] / m[col][col]
                for c in col..<cols {
                    m[row][c] -= factor * m[col][c]
                }
            }
        }

        return .integer(rank)
    }
}

// MARK: - Inverse

struct InverseOperation: MathOperation {
    static var name = "inverse"
    static var arguments = ["matrix"]
    static var help = "Calculate matrix inverse: inverse matrix"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix = try parseMatrix(args[0])

        let n = matrix.count
        guard n == matrix[0].count else {
            throw OperationError.invalidValue("Inverse requires square matrix")
        }

        return .matrix(try inverseUsingGaussJordan(matrix))
    }
}

// MARK: - Matrix Multiply

struct MatrixMultiplyOperation: MathOperation {
    static var name = "matrix_multiply"
    static var arguments = ["matrix1", "matrix2"]
    static var help = "Multiply matrices: matrix_multiply matrix1 matrix2"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let matrix1 = try parseMatrix(args[0])
        let matrix2 = try parseMatrix(args[1])

        let m = matrix1.count
        let n = matrix1[0].count
        let p = matrix2[0].count

        guard n == matrix2.count else {
            throw OperationError.matrixDimensionMismatch
        }

        var result = Array(repeating: Array(repeating: 0.0, count: p), count: m)

        for i in 0..<m {
            for j in 0..<p {
                for k in 0..<n {
                    result[i][j] += matrix1[i][k] * matrix2[k][j]
                }
            }
        }

        return .matrix(result)
    }
}

// MARK: - Identity Matrix

struct IdentityOperation: MathOperation {
    static var name = "identity"
    static var arguments = ["n"]
    static var help = "Create identity matrix: identity n"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let n = try parseInt(args[0], argumentName: "n")

        guard n > 0 else {
            throw OperationError.invalidValue("Matrix size must be positive")
        }

        var matrix = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        for i in 0..<n {
            matrix[i][i] = 1.0
        }

        return .matrix(matrix)
    }
}

// MARK: - Zeros Matrix

struct ZerosOperation: MathOperation {
    static var name = "zeros"
    static var arguments = ["rows", "cols"]
    static var help = "Create zero matrix: zeros rows cols"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let rows = try parseInt(args[0], argumentName: "rows")
        let cols = try parseInt(args[1], argumentName: "cols")

        guard rows > 0 && cols > 0 else {
            throw OperationError.invalidValue("Matrix dimensions must be positive")
        }

        let matrix = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        return .matrix(matrix)
    }
}

// MARK: - Ones Matrix

struct OnesOperation: MathOperation {
    static var name = "ones"
    static var arguments = ["rows", "cols"]
    static var help = "Create matrix of ones: ones rows cols"
    static var category = OperationCategory.matrix

    static func execute(args: [Any]) throws -> OperationResult {
        let rows = try parseInt(args[0], argumentName: "rows")
        let cols = try parseInt(args[1], argumentName: "cols")

        guard rows > 0 && cols > 0 else {
            throw OperationError.invalidValue("Matrix dimensions must be positive")
        }

        let matrix = Array(repeating: Array(repeating: 1.0, count: cols), count: rows)
        return .matrix(matrix)
    }
}

// MARK: - Diagonal Matrix

struct DiagonalOperation: MathOperation {
    static var name = "diagonal"
    static var arguments = ["values..."]
    static var help = "Create diagonal matrix: diagonal value1 value2 ..."
    static var category = OperationCategory.matrix
    static var isVariadic = true

    static func execute(args: [Any]) throws -> OperationResult {
        var values: [Double] = []

        for arg in args {
            let value = try parseDouble(arg, argumentName: "value")
            values.append(value)
        }

        guard !values.isEmpty else {
            throw OperationError.invalidValue("Diagonal requires at least one value")
        }

        let n = values.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        for i in 0..<n {
            matrix[i][i] = values[i]
        }

        return .matrix(matrix)
    }
}
