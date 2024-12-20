import UnixSignals

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
 
 // TODO: notify on changes to width and cache
 public static func callHeight() -> Int {
  var size = winsize()
#if os(Windows) || os(Linux)
  if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0 {
   return Int(size.ws_row)
  } else {
   return -1
  }
#else
  if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 {
   return Int(size.ws_row)
  } else {
   return -1
  }
#endif
 }
 
 @inlinable public static var width: Int { callWidth() }
 @inlinable public static var height: Int { callHeight() }
#endif
 
 public static func write(_ str: String) {
  str.withCString { _ = unistd.write(STDOUT_FILENO, $0, strlen($0)) }
 }
 
 @inlinable public static func appendInput(_ input: String) {
  write("\r" + input)
 }
 
 @inlinable public static func clearLine() {
  write("\r")
 }
 
#if os(WASI)
 @inlinable public static func clearInput(_ width: Int) {
  write(String(repeating: .space, count: width) + "\r")
 }
#else
 @inlinable public static func clearScrollback(_ count: Int = Shell.height) {
  for _ in 0 ..< count {
   write("\u{001B}[1A")
   write(String(repeating: .space, count: width) + "\r")
  }
 }
 
 @inlinable public static func clearScrollback(_ count: Int = Shell.height, width: Int) {
  for _ in 0 ..< count {
   write("\u{001B}[1A")
   write(String(repeating: .space, count: width) + "\r")
  }
 }

 @inlinable public static func clearInput(_ width: Int = Shell.width) {
  appendInput(String(repeating: .space, count: width))
 }
#endif
 @inlinable
 public static func onInterruption(_ trap: (@convention(c) (Int32) -> Void)!) {
  signal(SIGINT, trap)
 }
 
 @inlinable
 public static func onInterruption(_ trap: @escaping () async -> Void) async {
  let signals = await UnixSignalsSequence(trapping: .sigint)
  Task.detached {
   for await signal in signals where signal == .sigint {
    await trap()
   }
  }
//  let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
//  sigIntSource.setEventHandler(qos: .default, flags: [], handler: trap)
//  sigIntSource.resume()
 }
}

// MARK: - Input
extension Shell {
 typealias InputHandler = (bell: Bool, (InputKey) async -> Bool)
 private static var inputHandlers: [AnyHashable: InputHandler] = [:]

 public enum InputKey: Equatable {
  public enum ArrowKey {
   case up
   case down
   case right
   case left
  }

  case space
  case arrowKey(ArrowKey)
  case `return`
  case key(Character)

  static var up: Self { .arrowKey(.up) }
  static var down: Self { .arrowKey(.down) }
  static var right: Self { .arrowKey(.right) }
  static var left: Self { .arrowKey(.left) }

  public var rawValue: String {
   switch self {
   case .space: " "
   case .arrowKey(let key):
    switch key {
    case .up: "\u{1b}[A"
    case .down: "\u{1b}[B"
    case .right: "\u{1b}[C"
    case .left: "\u{1b}[D"
    }
   case .return: "\n"
   case .key(let char): "\(char)"
   }
  }
 }

 open class InputParser {
  public static let `default` = InputParser()
  public var partial = 0

  open func parse(character: Character) -> InputKey? {
   switch partial {
   case 0:
    switch character {
    case "\u{1b}": partial = 1
     return nil
    case " ": return .space
    case "\n": return .return
    default: return .key(character)
    }
   case 1 where character == "[": partial = 2
    return nil
   case 2:
    switch character {
    case "A": partial = 0
     return .arrowKey(.up)
    case "B": partial = 0
     return .arrowKey(.down)
    case "C": partial = 0
     return .arrowKey(.right)
    case "D": partial = 0
     return .arrowKey(.left)
    default: break
    }
    fallthrough
   default: partial = 0
    return nil
   }
  }
 }

 public static var stdInSource: DispatchSourceRead?
 public static func setInputMode() {
  var tattr = termios()
  tcgetattr(STDIN_FILENO, &tattr)
  tattr.c_lflag &= ~tcflag_t(ECHO | ICANON)
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr)
 }
 
 public static func resetInputMode() {
  // Reset ECHO and ICANON values:
  var tattr = termios()
  tcgetattr(STDIN_FILENO, &tattr)
  tattr.c_lflag |= tcflag_t(ECHO | ICANON)
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr)
 }

 private static var tputBelProcess: Process?
 private static let tputPath = "/usr/bin/tput"
 private static func spawnBell() {
  guard FileManager.default.fileExists(atPath: tputPath) else { return }
  let proc = Process()
  proc.qualityOfService = .userInitiated
  proc.executableURL = URL(fileURLWithPath: tputPath)
  proc.arguments = ["bel"]
  tputBelProcess = proc
 }

 public static func ringBell() {
  if let tputBelProcess {
   if tputBelProcess.isRunning {
    tputBelProcess.terminate()
    spawnBell()
   }
   do {
    try tputBelProcess.run()
   } catch {
    self.tputBelProcess = nil
    ringBell()
   }
  } else {
   spawnBell()
   ringBell()
  }
 }
 
 public static var inputParser: InputParser = .default
 public static func handleInput(
  bell: Bool = false, with parser: InputParser? = nil,
  _ send: @escaping (InputKey) async -> Bool
 ) {
  Shell.inputHandlers[0] = (bell, send)
  if stdInSource == nil {
   setInputMode()
   let stdInSource =
    DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)

   stdInSource.setEventHandler(qos: .userInitiated, flags: []) {
    let data = FileHandle.standardInput.availableData
    guard let string = String(data: data, encoding: .utf8) else {
     return
    }

    func handleChar(_ char: Character) {
     if char == "\u{04}" {
      self.resetInputMode()
     }
    }

    let parser = parser ?? Self.inputParser
    for char in string {
     switch (parser ).parse(character: char) {
     case let .some(key):
      for (bell, handler) in Shell.inputHandlers.values {
       Task {
        let didSend = await handler(key)
        if bell, !didSend { Shell.ringBell() }
       }
      }

     default: handleChar(char)
     }
    }
   }
   stdInSource.resume()
   self.stdInSource = stdInSource
  }
 }
}

// MARK: - Error
// https://github.com/JohnSundell/ShellOut/blob/master/Sources/ShellOut.swift
public struct ShellError: Swift.Error {
 /// The termination status of the command that was run
 public let terminationStatus: Int32
 public var _code: Int { Int(terminationStatus) }
 /// The error message as a UTF8 string, as returned through `STDERR`
 public var message: String { errorData.shellOutput() }
 /// The raw error buffer data, as returned through `STDERR`
 public let errorData: Data
 /// The raw input buffer data, as retuned through `STDIN`
 public let inputData: Data
 /// The raw output buffer data, as retuned through `STDOUT`
 public let outputData: Data
 /// The output of the command as a UTF8 string, as returned through `STDIN`
 public var input: String { inputData.shellOutput() }
 /// The output of the command as a UTF8 string, as returned through `STDOUT`
 public var output: String { outputData.shellOutput() }
}

extension ShellError: LocalizedError {
 public var errorDescription: String? { message.wrapped }
 public var localizedDescription: String {
  message.wrapped ?? _code.description
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
