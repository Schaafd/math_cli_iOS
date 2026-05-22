//
//  MathCLITests.swift
//  MathCLITests
//

import XCTest
import SwiftData
@testable import MathCLI

final class MathCLITests: XCTestCase {
    private var sessionID: UUID!

    override func setUpWithError() throws {
        sessionID = UUID()
        VariableStore.shared.setSession(sessionID)
        FunctionRegistry.shared.setSession(sessionID)
        VariableStore.shared.clearAll()
        FunctionRegistry.shared.clearAll()
    }

    override func tearDownWithError() throws {
        VariableStore.shared.clearAll()
        FunctionRegistry.shared.clearAll()
        sessionID = nil
    }

    func testOperationExecutorBasicCommandsChainsAndReferences() throws {
        let executor = OperationExecutor()

        XCTAssertEqual(try executor.execute(command: "add 5 10").description, "15")
        XCTAssertEqual(try executor.execute(command: "add 5 10 | multiply 2").description, "30")

        _ = try executor.execute(command: "set x 42")
        XCTAssertEqual(try executor.execute(command: "multiply $x 2").description, "84")

        XCTAssertEqual(try executor.execute(command: "add 2 3").description, "5")
        XCTAssertEqual(try executor.execute(command: "multiply $ 4").description, "20")
        XCTAssertEqual(try executor.execute(command: "multiply $ans 2").description, "40")
    }

    func testOperationExecutorErrors() throws {
        let executor = OperationExecutor()

        XCTAssertThrowsError(try executor.execute(command: "unknown_operation 1 2")) { error in
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }

        XCTAssertThrowsError(try executor.execute(command: "add 1")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid argument count"))
        }

        XCTAssertThrowsError(try executor.execute(command: "divide 1 0")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Division by zero"))
        }
    }

    func testArithmeticStatisticsNumberTheoryMatrixAndCalculusOperations() throws {
        XCTAssertEqual(try AddOperation.execute(args: [5, 10]).description, "15")
        XCTAssertEqual(try MeanOperation.execute(args: [2, 4, 6, 8]).description, "5")
        XCTAssertEqual(try GcdOperation.execute(args: [84, 30]).description, "6")
        XCTAssertEqual(try DetOperation.execute(args: ["[[1,2],[3,4]]"]).description, "-2")
        XCTAssertEqual(try InverseOperation.execute(args: ["[[1,0],[0,2]]"]).description, "[\n  [1, 0],\n  [0, 0.5]\n]")
        XCTAssertEqual(try DerivativeOperation.execute(args: [3, 2, 4]).description, "24")
        XCTAssertEqual(try IntegrateOperation.execute(args: [2, 1, 0, 3]).description, "9")

        XCTAssertThrowsError(try InverseOperation.execute(args: ["[[1,2],[2,4]]"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("singular"))
        }
        XCTAssertThrowsError(try DetOperation.execute(args: ["[[1,2],[3]]"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Matrix dimension mismatch"))
        }
        XCTAssertThrowsError(try TaylorOperation.execute(args: ["tan", 0, 3])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unsupported function"))
        }
    }

    func testDataTransformPlottingAndExportImportOperations() throws {
        XCTAssertEqual(try NormalizeDataOperation.execute(args: [5, 5, 5]).description, "[0.5, 0.5, 0.5]")
        XCTAssertEqual(try SampleDataOperation.execute(args: [2, 10, 20, 30]).description.components(separatedBy: ",").count, 2)
        XCTAssertTrue(try PlotHistOperation.execute(args: [3, 4, 4, 4]).description.contains("constant value 4"))
        XCTAssertThrowsError(try CorrelationMatrixOperation.execute(args: ["1,1,1", "2,3,4"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("non-constant"))
        }

        let executor = OperationExecutor()
        _ = try executor.execute(command: "set exportedValue 123")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mathcli-vars-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(try ExportVarsOperation.execute(args: [url.path]).description.contains("Variables exported"))
        VariableStore.shared.clearAll()
        XCTAssertNil(VariableStore.shared.get(name: "exportedValue"))

        XCTAssertTrue(try ImportVarsOperation.execute(args: [url.path]).description.contains("Variables imported"))
        XCTAssertEqual(VariableStore.shared.get(name: "exportedValue")?.description, "123")
    }

    func testVariableStoreAndFunctionRegistrySessionScope() throws {
        let firstSession = UUID()
        let secondSession = UUID()

        VariableStore.shared.setSession(firstSession)
        FunctionRegistry.shared.setSession(firstSession)
        VariableStore.shared.set(name: "scoped", value: .number(7))
        FunctionRegistry.shared.define(name: "double", parameters: ["x"], body: "multiply $x 2")

        VariableStore.shared.setSession(secondSession)
        FunctionRegistry.shared.setSession(secondSession)
        XCTAssertNil(VariableStore.shared.get(name: "scoped"))
        XCTAssertFalse(FunctionRegistry.shared.exists(name: "double"))

        VariableStore.shared.setSession(firstSession)
        FunctionRegistry.shared.setSession(firstSession)
        XCTAssertEqual(VariableStore.shared.get(name: "scoped")?.description, "7")
        XCTAssertTrue(FunctionRegistry.shared.exists(name: "double"))
        XCTAssertEqual(try OperationExecutor().execute(command: "double 9").description, "18")

        VariableStore.shared.clearAll()
        FunctionRegistry.shared.clearAll()
        XCTAssertNil(VariableStore.shared.get(name: "scoped"))
        XCTAssertFalse(FunctionRegistry.shared.exists(name: "double"))
    }

    @MainActor
    func testSessionManagerAndHistoryManagerWithInMemorySwiftData() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Session.self, HistoryEntry.self, configurations: config)
        let manager = SessionManager(modelContext: container.mainContext)

        let session = manager.createSession(name: "Test Session")
        manager.switchToSession(session)
        XCTAssertEqual(manager.activeSession?.name, "Test Session")

        let history = HistoryManager(modelContext: container.mainContext, session: session)
        history.addEntry(command: "add 1 2", result: "3")
        XCTAssertEqual(session.entries.count, 1)
        XCTAssertEqual(history.searchHistory(query: "add").count, 1)

        let entry = try XCTUnwrap(session.entries.first)
        history.bookmark(entry: entry, name: "Useful")
        XCTAssertEqual(history.getBookmarks().count, 1)

        history.removeBookmark(entry: entry)
        XCTAssertEqual(history.getBookmarks().count, 0)

        history.deleteEntry(entry)
        XCTAssertEqual(history.entries.count, 0)
    }

    @MainActor
    func testSessionArchiveExportSchema() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Session.self, HistoryEntry.self, configurations: config)
        let session = Session(name: "Export Test", isActive: true)
        let entry = HistoryEntry(command: "add 1 2", result: "3", isBookmarked: true, bookmarkName: "sum", session: session)

        container.mainContext.insert(session)
        container.mainContext.insert(entry)
        session.entries.append(entry)
        try container.mainContext.save()

        let document = try makeMathCLIJSONDocument(from: [session])
        let data = try XCTUnwrap(document.text.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(MathCLISessionArchive.self, from: data)

        XCTAssertEqual(archive.version, 1)
        XCTAssertEqual(archive.sessions.first?.name, "Export Test")
        XCTAssertEqual(archive.sessions.first?.commands.first?.command, "add 1 2")
        XCTAssertEqual(archive.sessions.first?.commands.first?.result, "3")
        XCTAssertEqual(archive.sessions.first?.commands.first?.bookmarkName, "sum")
    }
}
