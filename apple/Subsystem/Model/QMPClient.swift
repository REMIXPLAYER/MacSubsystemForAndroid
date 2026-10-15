// Mac Subsystem for Android - a tiny client for QEMU's QMP monitor (JSON over a Unix
// socket), used to resize the memory balloon while Android runs.
//
//   <- {"QMP": {...}}                      greeting
//   -> {"execute": "qmp_capabilities"}     <- {"return": {}}
//   -> {"execute": "balloon", "arguments": {"value": <bytes>}}
//
// Licensed under the GNU General Public License v3 or later.

import Foundation

enum QMPClient {
    static var socketURL: URL { SubsystemPaths.runtime.appendingPathComponent("qmp.sock") }

    /// Run one command. Returns QEMU's reply, or nil if QEMU couldn't be reached.
    @discardableResult
    static func execute(_ command: String, arguments: [String: Any]? = nil) -> [String: Any]? {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return nil }
        defer { Darwin.close(socket) }
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var yes: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(socketURL.path.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            path.withUnsafeBytes { raw.copyMemory(from: $0) }
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return nil }

        var reader = LineReader(socket: socket)
        guard reader.next() != nil else { return nil } // greeting
        guard send(socket, ["execute": "qmp_capabilities"]), reader.reply() != nil else { return nil }
        var request: [String: Any] = ["execute": command]
        if let arguments { request["arguments"] = arguments }
        guard send(socket, request) else { return nil }
        return reader.reply()
    }

    private static func send(_ socket: Int32, _ object: [String: Any]) -> Bool {
        guard var data = try? JSONSerialization.data(withJSONObject: object) else { return false }
        data.append(0x0a)
        return data.withUnsafeBytes { Darwin.send(socket, $0.baseAddress!, $0.count, 0) == $0.count }
    }

    /// Reads newline-separated JSON objects, skipping asynchronous events.
    private struct LineReader {
        let socket: Int32
        var buffer = Data()

        mutating func next() -> [String: Any]? {
            while true {
                if let newline = buffer.firstIndex(of: 0x0a) {
                    let line = buffer[buffer.startIndex..<newline]
                    buffer.removeSubrange(buffer.startIndex...newline)
                    if let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] {
                        return object
                    }
                    continue
                }
                var chunk = [UInt8](repeating: 0, count: 4096)
                let n = recv(socket, &chunk, chunk.count, 0)
                if n <= 0 { return nil }
                buffer.append(contentsOf: chunk[0..<n])
            }
        }

        mutating func reply() -> [String: Any]? {
            while let object = next() {
                if object["return"] != nil || object["error"] != nil { return object }
            }
            return nil
        }
    }
}
