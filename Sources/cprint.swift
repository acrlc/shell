@inline(__always)
public func swiftprintf(_ format: String, _ arguments: CVarArg...) {
 #if os(WASI) || os(Windows) || os(Linux)
 print(String(format: format, arguments: arguments), terminator: "")
 #else
 print(String(format: format, arguments), terminator: "")
 #endif
}
