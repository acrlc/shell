#if os(Linux)
import var Glibc.EINVAL
import var Glibc.ERANGE
import func Glibc.strerror_r
#elseif os(macOS)
import var Darwin.EINVAL
import var Darwin.ERANGE
import func Darwin.strerror_r
#endif

#if os(Linux) || os(macOS) || os(iOS)
import Foundation

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

private final class CStringArray {
 /// The null-terminated array of C string pointers.
 public let cArray: [UnsafeMutablePointer<Int8>?]

 /// Creates an instance from an array of strings.
 public init(_ array: [String]) {
  cArray = array.map { $0.withCString { strdup($0) } } + [nil]
 }

 deinit {
  for case let element? in cArray {
   free(element)
  }
 }
}

public enum _POSIXError: LocalizedError {
 case execv(executable: String, errno: Int32), termination(Int32)

 public var status: Int32 {
  switch self {
  case .execv(_, let code): code
  case .termination(let code): code
  }
 }

 public var _code: Int { Int(status) }

 public var errorDescription: String? {
  switch self {
  case .execv(let executablePath, let errno):
   "execv failed: \(strerror(errno)): \(executablePath)"
  case .termination(let code): "exit: \(code)"
  }
 }
}

// from https://www.github.com/mxcl/swift-sh
public func execv(
 _ command: String, _ arguments: some Sequence<String>
) throws {
 let args = CStringArray([command] + arguments)

 guard execv(command, args.cArray) != -1 else {
  throw _POSIXError.execv(executable: command, errno: errno)
 }

 // note: impossible?
 fatalError()
}

public func execv(_ command: String, with arguments: String...) throws {
 let args = CStringArray([command] + arguments)

 guard execv(command, args.cArray) != -1 else {
  throw _POSIXError.execv(executable: command, errno: errno)
 }
}

public func execv(_ name: CommandName, with arguments: String...) throws {
 let command = "/usr/bin/env"
 let subcommand = name.rawValue
 let arguments = ["-S", subcommand] + arguments
 
 let args = CStringArray(arguments)

 guard execv(command, args.cArray) != -1 else {
  throw _POSIXError.execv(executable: subcommand, errno: errno)
 }
}

public func execv(
 _ name: CommandName, _ arguments: some Sequence<String>
) throws {
 let command = "/usr/bin/env"
 let subcommand = name.rawValue
 let arguments = ["-S", subcommand] + arguments
 let args = CStringArray(arguments)

 guard execv(command, args.cArray) != -1 else {
  throw _POSIXError.execv(executable: subcommand, errno: errno)
 }
}
#endif
