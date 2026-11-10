#if os(macOS)
    import Darwin
    import Foundation

    /// A stable, per-workspace advisory lock, held only during preparation or cleanup.
    /// Never unlink the file: doing so could let another process lock a different inode.
    final class LocalWorkspaceLock {
        private let descriptor: Int32

        init(state: URL) throws {
            let manager = FileManager.default
            try manager.createDirectory(at: state.deletingLastPathComponent(), withIntermediateDirectories: true)
            let path = state.appendingPathExtension("operation-lock").path
            let descriptor = open(path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            var information = stat()
            var published = stat()
            guard fstat(descriptor, &information) == 0,
                  (information.st_mode & S_IFMT) == S_IFREG,
                  information.st_uid == getuid(), information.st_nlink == 1,
                  lstat(path, &published) == 0,
                  published.st_dev == information.st_dev, published.st_ino == information.st_ino
            else {
                close(descriptor)
                throw LocalActionError(message: "The workspace operation lock is not an owned regular file: \(path)")
            }
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
                let code = errno
                close(descriptor)
                if code == EWOULDBLOCK || code == EAGAIN {
                    throw LocalActionError(message: "This PR workspace is being prepared or cleaned. Try again after that finishes.")
                }
                throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
            }
            self.descriptor = descriptor
        }

        deinit {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
    }
#endif
