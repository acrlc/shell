public extension CommandLine {
 static var usage: String?
}

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
