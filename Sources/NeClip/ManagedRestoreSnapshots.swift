import Darwin
import Foundation

enum UserDataErasureError: LocalizedError, Equatable {
    case managedSnapshotsRemain

    var errorDescription: String? {
        "История и сниппеты удалены из основной базы. Не удалось удалить внутренние резервные копии — повторите очистку."
    }
}

/// Legacy restore snapshots use a reserved UUID name next to the active DB.
/// Explicit exports have no such name and may live anywhere; never scan recursively.
enum ManagedRestoreSnapshots {
    private static let prefix = "neclip-before-restore-"
    private static let suffixes = [".sqlite", ".sqlite.json", ".sqlite-wal", ".sqlite-shm", ".sqlite-journal"]

    private static func isManagedName(_ name: String) -> Bool {
        guard name.hasPrefix(prefix), let suffix = suffixes.first(where: { name.hasSuffix($0) }) else {
            return false
        }
        let identifier = String(name.dropFirst(prefix.count).dropLast(suffix.count))
        guard let uuid = UUID(uuidString: identifier) else { return false }
        return uuid.uuidString == identifier.uppercased()
    }

    static func removeAll(beside databaseURL: URL) throws {
        let directory = databaseURL.deletingLastPathComponent()
        // Resolve each child relative to one directory descriptor. Never follow
        // a child symlink or recursively remove a directory substituted for a file.
        let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw UserDataErasureError.managedSnapshotsRemain }
        defer { close(descriptor) }

        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: directory.path) }
        catch { throw UserDataErasureError.managedSnapshotsRemain }
        let activeName = databaseURL.lastPathComponent
        let activeFiles = Set([activeName, activeName + ".json", activeName + "-wal",
                               activeName + "-shm", activeName + "-journal"])
        var failed = false
        for name in names where isManagedName(name) && !activeFiles.contains(name) {
            var info = stat()
            guard fstatat(descriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                if errno != ENOENT { failed = true }
                continue
            }
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
                failed = true
                continue
            }
            // unlinkat never follows a symlink and, without AT_REMOVEDIR,
            // refuses directories even if the entry changes after fstatat.
            if unlinkat(descriptor, name, 0) != 0, errno != ENOENT { failed = true }
        }
        if failed { throw UserDataErasureError.managedSnapshotsRemain }
    }
}
