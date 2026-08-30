import Darwin
import Foundation

public enum MoCompanionTransportError: LocalizedError, Sendable {
    case unavailable(String)
    case protocolFailure(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message), .protocolFailure(let message): message
        }
    }
}

public enum MoCompanionPaths {
    /// The login user's real home directory, even when App Sandbox remaps
    /// Foundation's home-directory APIs into the app container.
    public static var userHomeDirectory: URL {
        if let passwordEntry = getpwuid(getuid()),
            let path = String(validatingUTF8: passwordEntry.pointee.pw_dir)
        {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static func socketURL(
        bundleIdentifier: String,
        homeDirectory: URL = userHomeDirectory
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data/tmp/MoCLI", isDirectory: true)
            .appendingPathComponent("mo.sock")
    }
}

public final class MoLocalSocketServer: @unchecked Sendable {
    public typealias Handler = @Sendable (MoCompanionRequest) async -> MoCompanionResponse

    private static let maximumFrameSize = 64 * 1_024

    private let path: String
    private let handler: Handler
    private let queue = DispatchQueue(label: "com.danielcorin.Mo.cli", qos: .userInitiated)
    private let clientQueue = DispatchQueue(
        label: "com.danielcorin.Mo.cli.clients",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let clientSlots = DispatchSemaphore(value: 8)
    private let stateLock = NSLock()
    private var descriptor: Int32 = -1
    private var running = false
    private var generation: UInt = 0

    public init(path: String, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    public func start() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !running else { return }

        let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        Darwin.chmod(directory.path, S_IRWXU)
        Darwin.unlink(path)

        let serverDescriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverDescriptor >= 0 else {
            throw MoCompanionTransportError.unavailable(
                "Could not create Mo's local command socket."
            )
        }
        var shouldCloseDescriptor = true
        defer {
            if shouldCloseDescriptor {
                Darwin.close(serverDescriptor)
                Darwin.unlink(path)
            }
        }

        var address = try Self.address(for: path)
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverDescriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0, Darwin.listen(serverDescriptor, 16) == 0 else {
            throw MoCompanionTransportError.unavailable(
                "Could not start Mo's local command service."
            )
        }

        Darwin.chmod(path, S_IRUSR | S_IWUSR)
        descriptor = serverDescriptor
        running = true
        generation &+= 1
        let currentGeneration = generation
        shouldCloseDescriptor = false
        queue.async { [weak self] in
            self?.acceptLoop(descriptor: serverDescriptor, generation: currentGeneration)
        }
    }

    public func stop() {
        stateLock.lock()
        running = false
        generation &+= 1
        let serverDescriptor = descriptor
        descriptor = -1
        stateLock.unlock()

        if serverDescriptor >= 0 {
            Darwin.shutdown(serverDescriptor, SHUT_RDWR)
            Darwin.close(serverDescriptor)
        }
        Darwin.unlink(path)
    }

    deinit {
        stop()
    }

    private func acceptLoop(descriptor: Int32, generation: UInt) {
        while isRunning(descriptor: descriptor, generation: generation) {
            let client = Darwin.accept(descriptor, nil, nil)
            guard client >= 0 else {
                if errno == EINTR { continue }
                if isRunning(descriptor: descriptor, generation: generation) { continue }
                return
            }

            guard clientSlots.wait(timeout: .now()) == .success else {
                Darwin.close(client)
                continue
            }
            Self.configure(client: client)
            handle(client: client)
        }
    }

    private func handle(client: Int32) {
        let handler = handler
        let clientQueue = clientQueue
        let clientSlots = clientSlots

        clientQueue.async {
            let request: MoCompanionRequest
            do {
                let data = try Self.readFrame(from: client)
                request = try MoCompanionProtocol.makeDecoder().decode(
                    MoCompanionRequest.self,
                    from: data
                )
            } catch {
                Self.finish(
                    client: client,
                    response: MoCompanionResponse(
                        requestID: UUID(),
                        success: false,
                        message: error.localizedDescription,
                        errorCode: "protocol_failure"
                    ),
                    clientSlots: clientSlots
                )
                return
            }

            Task {
                let response = await handler(request)
                clientQueue.async {
                    Self.finish(client: client, response: response, clientSlots: clientSlots)
                }
            }
        }
    }

    private func isRunning(descriptor: Int32, generation: UInt) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return running && self.descriptor == descriptor && self.generation == generation
    }

    fileprivate static func configure(client: Int32) {
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        let timeoutSize = socklen_t(MemoryLayout<timeval>.size)
        Darwin.setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, timeoutSize)
        Darwin.setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, timeoutSize)

        var noSignal = Int32(1)
        Darwin.setsockopt(
            client,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSignal,
            socklen_t(MemoryLayout<Int32>.size)
        )
    }

    private static func finish(
        client: Int32,
        response: MoCompanionResponse,
        clientSlots: DispatchSemaphore
    ) {
        defer {
            Darwin.close(client)
            clientSlots.signal()
        }
        try? writeFrame(MoCompanionProtocol.makeEncoder().encode(response), to: client)
    }

    fileprivate static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        guard path.utf8CString.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw MoCompanionTransportError.unavailable(
                "Mo's local command service path is too long."
            )
        }
        path.withCString { source in
            _ = Darwin.strlcpy(
                &address.sun_path.0,
                source,
                MemoryLayout.size(ofValue: address.sun_path)
            )
        }
        return address
    }

    fileprivate static func writeFrame(_ data: Data, to descriptor: Int32) throws {
        guard data.count <= maximumFrameSize else {
            throw MoCompanionTransportError.protocolFailure(
                "The local command request exceeded 64 KB."
            )
        }
        var length = UInt32(data.count).bigEndian
        try withUnsafeBytes(of: &length) { try writeAll($0, to: descriptor) }
        try data.withUnsafeBytes { try writeAll($0, to: descriptor) }
    }

    fileprivate static func readFrame(from descriptor: Int32) throws -> Data {
        var length = UInt32(0)
        try withUnsafeMutableBytes(of: &length) { try readAll($0, from: descriptor) }
        let count = Int(UInt32(bigEndian: length))
        guard count <= maximumFrameSize else {
            throw MoCompanionTransportError.protocolFailure(
                "The local command response exceeded 64 KB."
            )
        }
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { try readAll($0, from: descriptor) }
        return data
    }

    private static func writeAll(
        _ bytes: UnsafeRawBufferPointer,
        to descriptor: Int32
    ) throws {
        var written = 0
        while written < bytes.count {
            let result = Darwin.write(
                descriptor,
                bytes.baseAddress!.advanced(by: written),
                bytes.count - written
            )
            if result < 0, errno == EINTR { continue }
            guard result > 0 else {
                throw MoCompanionTransportError.unavailable(
                    "Mo's local command service disconnected."
                )
            }
            written += result
        }
    }

    private static func readAll(
        _ bytes: UnsafeMutableRawBufferPointer,
        from descriptor: Int32
    ) throws {
        var readCount = 0
        while readCount < bytes.count {
            let result = Darwin.read(
                descriptor,
                bytes.baseAddress!.advanced(by: readCount),
                bytes.count - readCount
            )
            if result < 0, errno == EINTR { continue }
            guard result > 0 else {
                throw MoCompanionTransportError.unavailable(
                    "Mo's local command service disconnected."
                )
            }
            readCount += result
        }
    }
}

public enum MoLocalSocketClient {
    public static func send(
        _ request: MoCompanionRequest,
        path: String
    ) throws -> MoCompanionResponse {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw MoCompanionTransportError.unavailable("Could not connect to Mo.")
        }
        defer { Darwin.close(descriptor) }
        MoLocalSocketServer.configure(client: descriptor)

        var address = try MoLocalSocketServer.address(for: path)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            throw MoCompanionTransportError.unavailable(
                "Mo is not running. Open it and try again."
            )
        }

        try MoLocalSocketServer.writeFrame(
            MoCompanionProtocol.makeEncoder().encode(request),
            to: descriptor
        )
        let data = try MoLocalSocketServer.readFrame(from: descriptor)
        return try MoCompanionProtocol.makeDecoder().decode(
            MoCompanionResponse.self,
            from: data
        )
    }
}
