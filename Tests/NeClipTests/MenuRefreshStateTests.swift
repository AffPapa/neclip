import XCTest
@testable import NeClip

final class MenuRefreshStateTests: XCTestCase {
    func testControllerUsesDomainGuardsAndRejectsObsoleteCompletions() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/NeClip/StatusBarController.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("if domains.contains(.clips)"))
        XCTAssertTrue(source.contains("try domains.contains(.snippets)"))
        XCTAssertTrue(source.contains("refreshState.invalidate(domain)"))
        XCTAssertTrue(source.contains("self.refreshState.accept(generation)"))
        XCTAssertFalse(source.contains("refreshGeneration"))
    }

    func testInitialLoadAndUnchangedSnapshot() {
        var state = MenuRefreshState()
        XCTAssertEqual(state.domains, .all)
        XCTAssertTrue(state.accept(state.begin()))
        XCTAssertTrue(state.domains.isEmpty)
    }

    func testIndependentDomainsAvoidUnrelatedReads() {
        for domain in [StorageChangeDomain.clips, .snippets] {
            var state = MenuRefreshState()
            XCTAssertTrue(state.accept(state.begin()))
            state.invalidate(domain)
            XCTAssertEqual(state.domains, domain == .clips ? .clips : .snippets)
            XCTAssertTrue(state.accept(state.begin()))
            XCTAssertTrue(state.domains.isEmpty)
        }
    }

    func testChangesDuringReadRemainDirtyAndRejectStaleResult() {
        var state = MenuRefreshState()
        XCTAssertTrue(state.accept(state.begin()))
        state.invalidate(.clips)
        let obsolete = state.begin()
        state.invalidate(.snippets)
        XCTAssertFalse(state.accept(obsolete))
        XCTAssertEqual(state.domains, .all)
        XCTAssertTrue(state.accept(state.begin()))
    }

    func testErasureInvalidatesInFlightReadAndReloadsBothDomains() {
        var state = MenuRefreshState()
        let obsolete = state.begin()
        state.invalidate(.all)
        XCTAssertFalse(state.accept(obsolete))
        XCTAssertEqual(state.domains, .all)
        XCTAssertTrue(state.accept(state.begin()))
    }

    func testFailureRetainsDirtyWorkAndNewReadSupersedesOldRead() {
        var state = MenuRefreshState()
        let failed = state.begin()
        let retry = state.begin()
        XCTAssertEqual(state.domains, .all)
        XCTAssertFalse(state.accept(failed))
        XCTAssertTrue(state.accept(retry))
        state.invalidate(nil)
        XCTAssertEqual(state.domains, .all)
    }
}
