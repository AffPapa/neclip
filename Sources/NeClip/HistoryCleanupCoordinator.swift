import Foundation

@MainActor
protocol HistoryCaptureControlling: AnyObject {
    var isRunning: Bool { get }
    func stopAndDrainAsync() async
    func start()
}

enum HistoryCleanupError: LocalizedError {
    case captureUnavailable

    var errorDescription: String? {
        "Не удалось безопасно остановить запись истории. Повторите очистку после запуска NeClip."
    }
}

/// One application-owned gate for destructive history operations. The timer
/// stops on the main actor, but draining capture and deleting rows never block
/// it. Concurrent requests serialize; a failure still restores observation.
@MainActor
final class HistoryCleanupCoordinator {
    static let shared = HistoryCleanupCoordinator()

    private weak var capture: (any HistoryCaptureControlling)?
    private var pending: Task<Void, Never>?

    init(capture: (any HistoryCaptureControlling)? = nil) {
        self.capture = capture
    }

    func attach(_ capture: any HistoryCaptureControlling) {
        self.capture = capture
    }

    func run<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let previous = pending
        let task = Task { @MainActor [weak self] in
            await previous?.value
            guard let capture = self?.capture else { throw HistoryCleanupError.captureUnavailable }
            let wasRunning = capture.isRunning
            await capture.stopAndDrainAsync()
            // start() establishes a fresh pasteboard generation. It does not
            // clear the user's persistent pause, launch lock or one-shot flags.
            defer { if wasRunning { capture.start() } }
            return try await Task.detached(priority: .utility, operation: operation).value
        }
        pending = Task { _ = await task.result }
        return try await task.value
    }
}
