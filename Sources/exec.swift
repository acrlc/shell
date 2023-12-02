import Foundation

// from https://www.github.com/mxcl/swift-sh
public func exec(_ command: String, with arguments: [String]) throws -> Never {
 let args = CStringArray([command] + arguments)

 guard execv(command, args.cArray) != -1 else {
  throw POSIXError.execv(executable: command, errno: errno)
 }

 // note: impossible?
 fatalError()
}

#if os(Linux)
import var Glibc.EINVAL
import var Glibc.ERANGE
import func Glibc.strerror_r
#else
import var Darwin.EINVAL
import var Darwin.ERANGE
import func Darwin.strerror_r
#endif

public func strerror(_ code: Int32) -> String {
 var cap = 64
 while cap <= 16 * 1024 {
  var buf = [Int8](repeating: 0, count: cap)
  let err = strerror_r(code, &buf, buf.count)
  if err == EINVAL {
   return "unknown error \(code)"
  }
  if err == ERANGE {
   cap *= 2
   continue
  }
  if err != 0 {
   return "fatal: strerror_r: \(err)"
  }
  return "\(String(cString: buf)) (\(code))"
 }
 return "fatal: strerror_r: ERANGE"
}

public enum POSIXError: LocalizedError {
 case execv(executable: String, errno: Int32), code(Int32)

 public var _code: Int {
  switch self {
  case .execv(_, let code): return Int(code)
  case .code(let code): return Int(code)
  }
 }

 public var errorDescription: String? {
  switch self {
  case .execv(let executablePath, let errno):
   return "execv failed: \(strerror(errno)): \(executablePath)"
  case .code(let code): return code.description
  }
 }
}

private final class CStringArray {
 /// The null-terminated array of C string pointers.
 public let cArray: [UnsafeMutablePointer<Int8>?]

 /// Creates an instance from an array of strings.
 public init(_ array: [String]) {
  self.cArray = array.map { $0.withCString { strdup($0) } } + [nil]
 }

 deinit {
  for case let element? in cArray {
   free(element)
  }
 }
}
