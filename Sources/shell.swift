// A
public enum Shell {
 /// - Note: This should be replaced if the expected parser has the help command
 public var help: String? {
  get { CommandLine.usage }
  nonmutating set { CommandLine.usage = newValue }
 }

 public static let env = ProcessInfo.processInfo.environment

 #if !os(WASI)
 // TODO: notify on changes to width and cache
 public static func callWidth() -> Int {
  var size = winsize()
  #if os(Windows) || os(Linux)
  if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0 {
   return Int(size.ws_col)
  } else {
   return -1
  }
  #else
  if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 {
   return Int(size.ws_col)
  } else {
   return -1
  }
  #endif
 }

 @inlinable public static var width: Int { callWidth() }
 #endif

 @inlinable public static func appendInput(_ input: String) {
  fflush(stdout)
  print("\r" + input, terminator: .empty)
 }

 @inlinable public static func clearLine() {
  fflush(stdout)
  print("\r", terminator: .empty)
 }

 #if os(WASI)
 @inlinable public static func clearInput(_ width: Int) {
  fflush(stdout)
  print(
   "\r" + String(repeating: .space, count: width),
   terminator: .empty
  )
 }
 #else
 @inlinable public static func clearScrollback(_ count: Int = 1) {
  for _ in 0 ..< count {
   print("\u{001B}[1A", terminator: .empty)
   fflush(stdout)
   print(String(repeating: .space, count: width), terminator: "\r")
  }
 }

 @inlinable public static func clearInput(_ width: Int = Shell.width) {
  fflush(stdout)
  print(
   "\r" + String(repeating: .space, count: width),
   terminator: .empty
  )
 }
 #endif
}

// MARK: - Error
// https://github.com/JohnSundell/ShellOut/blob/master/Sources/ShellOut.swift
public struct ShellError: Swift.Error {
 /// The termination status of the command that was run
 public let terminationStatus: Int32
 public var _code: Int { Int(terminationStatus) }
 /// The error message as a UTF8 string, as returned through `STDERR`
 public var message: String { self.errorData.shellOutput() }
 /// The raw error buffer data, as returned through `STDERR`
 public let errorData: Data
 /// The raw input buffer data, as retuned through `STDIN`
 public let inputData: Data
 /// The raw output buffer data, as retuned through `STDOUT`
 public let outputData: Data
 /// The output of the command as a UTF8 string, as returned through `STDIN`
 public var input: String { self.inputData.shellOutput() }
 /// The output of the command as a UTF8 string, as returned through `STDOUT`
 public var output: String { self.outputData.shellOutput() }
}

extension ShellError: LocalizedError {
 public var errorDescription: String? { self.message.wrapped }
 public var localizedDescription: String {
  self.message.wrapped ?? _code.description
 }
}

extension Data {
 func shellOutput() -> String {
  guard let output = String(data: self, encoding: .utf8) else {
   return ""
  }

  guard !output.hasSuffix("\n") else {
   let endIndex = output.index(before: output.endIndex)
   return String(output[..<endIndex])
  }

  return output
 }
}

/* TODO: implement verbosity
 public enum Verbosity: Int {
  public init?(rawValue: Int) {
   switch rawValue {
   case 0: self = .none
   case 1: self = .some
   case 2: self = .optional
   case 3: self = .required
   default: return nil
   }
  }

  case none, some, optional, required
 }

 extension Verbosity: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
   lhs.rawValue < rhs.rawValue
  }
 }

 extension Verbosity: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) { self.init(rawValue: value)! }
 }
 */
