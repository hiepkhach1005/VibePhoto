import Darwin
import Foundation

final class FolderMonitor {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1

    func start(url: URL, onChange: @escaping @Sendable () -> Void) {
        stop()
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { [descriptor] in close(descriptor) }
        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        descriptor = -1
    }

    deinit { stop() }
}
