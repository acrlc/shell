@_exported import Core
@_exported import Extensions
#if !arch(wasm32)
@_exported import Paths
#endif
@_exported import struct Components.Regex
@_exported import Foundation

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

private extension FileHandle {
 var isStandard: Bool {
  self === FileHandle.standardOutput ||
   self === FileHandle.standardError ||
   self === FileHandle.standardInput
 }
}

private extension Data {
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

public struct CommandName: RawRepresentable {
 public let rawValue: String
 public init(rawValue: String) {
  self.rawValue = rawValue
 }

 public static let cd: Self = "cd"
 public static let cp: Self = "cp"
 public static let cat: Self = "cat"
 public static let curl: Self = "curl"
 public static let env: Self = "env"
 public static let bash: Self = "bash"
 public static let zsh: Self = "zsh"
 public static let sh: Self = "sh"
 public static let date: Self = "date"
 public static let sync: Self = "sync"
 public static let exec: Self = "exec"
 public static let node: Self = "node"
 public static let trap: Self = "trap"
 public static let echo: Self = "echo"
 public static let grep: Self = "grep"
 public static let git: Self = "git"
 public static let head: Self = "head"
 public static let tail: Self = "tail"
 public static let kill: Self = "kill"
 public static let brew: Self = "brew"
 public static let sudo: Self = "sudo"
 public static let chmod: Self = "chmod"
 public static let make: Self = "make"
 public static let exit: Self = "exit"
 public static let history: Self = "history"
 public static let clear: Self = "clear"
 public static let install: Self = "install"
 public static let parallel: Self = "parallel"
 public static let ls: Self = "ls"
 public static let ln: Self = "ln"
 public static let mkdir: Self = "mkdir"
 public static let ditto: Self = "ditto"
 public static let rmdir: Self = "rmdir"
 public static let mv: Self = "mv"
 public static let man: Self = "man"
 public static let sleep: Self = "sleep"
 public static let open: Self = "open"
 public static let jobs: Self = "jobs"
 public static let rm: Self = "rm"
 public static let pwd: Self = "pwd"
 public static let pkill: Self = "pkill"
 public static let which: Self = "which"
 public static let swift: Self = "swift"
 public static let locate: Self = "locate"
 public static let less: Self = "less"
 public static let compgen: Self = "compgen"
 public static let touch: Self = "touch"
 public static let timer: Self = "timer"
 public static let xcodebuild: Self = "xcodebuild"
 public static let xcodeselect: Self = "xcode-select"
 public static let xcrun: Self = "xcrun"
}

extension CommandName: ExpressibleByStringLiteral {
 public init(stringLiteral value: String) {
  self.init(rawValue: value)
 }
}

#if os(macOS) || os(Linux)
@discardableResult
public func output(
 command: String,
 _ args: some Sequence<String>,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> String {
 task.executableURL = URL(fileURLWithPath: task.shell)
 task.arguments = ["-c", command.appending(arguments: args)]
 // Because FileHandle's readabilityHandler might be called from a
 // different queue from the calling queue, avoid a data race by
 // protecting reads and writes to outputData and errorData on
 // a single dispatch queue.
 let inputQueue = DispatchQueue(label: "shell-input-queue")
 let outputQueue = DispatchQueue(label: "shell-output-queue")

 var inputData = Data()
 var outputData = Data()
 var errorData = Data()

 let inputPipe = Pipe()
 task.standardInput = inputPipe

 let outputPipe = pipe
 task.standardOutput = outputPipe

 let errorPipe = Pipe()
 task.standardError = errorPipe

 #if !os(Linux)
 inputPipe.fileHandleForReading.readabilityHandler = { handler in
  let data = handler.availableData
  inputQueue.async {
   inputData.append(data)
   inputHandle?.write(data)
  }
 }

 if !silent {
  outputPipe.fileHandleForReading.readabilityHandler = { handler in
   let data = handler.availableData
   outputQueue.async {
    outputData.append(data)
    outputHandle?.write(data)
   }
  }

  errorPipe.fileHandleForReading.readabilityHandler = { handler in
   let data = handler.availableData
   outputQueue.async {
    errorData.append(data)
    errorHandle?.write(data)
   }
  }
 }
 #endif

 try task.run()

 #if os(Linux)
 inputQueue.sync {
  inputData = inputPipe.fileHandleForReading.readDataToEndOfFile()
 }
 if !silent {
  outputQueue.sync {
   outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
   errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
  }
 }
 #endif

 task.waitUntilExit()

 if let handle = inputHandle, !handle.isStandard {
  handle.closeFile()
 }

 if !silent {
  if let handle = outputHandle, !handle.isStandard {
   handle.closeFile()
  }

  if let handle = errorHandle, !handle.isStandard {
   handle.closeFile()
  }

  #if !os(Linux)
  outputPipe.fileHandleForReading.readabilityHandler = nil
  errorPipe.fileHandleForReading.readabilityHandler = nil
  #endif
 }
 // Block until all writes have occurred to outputData and errorData,
 // and then read the data back out.
 return try outputQueue.sync {
  if task.terminationStatus != 0 {
   throw ShellError(
    terminationStatus: task.terminationStatus,
    errorData: errorData,
    inputData: inputData,
    outputData: outputData
   )
  }
  return outputData.shellOutput()
 }
}

@discardableResult
public func outputData(
 command: String,
 _ args: some Sequence<String>,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> Data {
 task.executableURL = URL(fileURLWithPath: task.shell)
 task.arguments = ["-c", command.appending(arguments: args)]
 let inputQueue = DispatchQueue(label: "shell-input-queue")
 let outputQueue = DispatchQueue(label: "shell-output-queue")

 var inputData = Data()
 var outputData = Data()
 var errorData = Data()

 let inputPipe = Pipe()
 task.standardInput = inputPipe

 let outputPipe = pipe
 task.standardOutput = outputPipe

 let errorPipe = Pipe()
 task.standardError = errorPipe

 #if !os(Linux)
 inputPipe.fileHandleForReading.readabilityHandler = { handler in
  let data = handler.availableData
  inputQueue.async {
   inputData.append(data)
   inputHandle?.write(data)
  }
 }

 if !silent {
  outputPipe.fileHandleForReading.readabilityHandler = { handler in
   let data = handler.availableData
   outputQueue.async {
    outputData.append(data)
    outputHandle?.write(data)
   }
  }

  errorPipe.fileHandleForReading.readabilityHandler = { handler in
   let data = handler.availableData
   outputQueue.async {
    errorData.append(data)
    errorHandle?.write(data)
   }
  }
 }
 #endif

 try task.run()

 #if os(Linux)
 inputQueue.sync {
  inputData = inputPipe.fileHandleForReading.readDataToEndOfFile()
 }
 if !silent {
  outputQueue.sync {
   outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
   errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
  }
 }
 #endif

 task.waitUntilExit()

 if let handle = inputHandle, !handle.isStandard {
  handle.closeFile()
 }

 if !silent {
  if let handle = outputHandle, !handle.isStandard {
   handle.closeFile()
  }

  if let handle = errorHandle, !handle.isStandard {
   handle.closeFile()
  }

  #if !os(Linux)
  outputPipe.fileHandleForReading.readabilityHandler = nil
  errorPipe.fileHandleForReading.readabilityHandler = nil
  #endif
 }
 return try outputQueue.sync {
  if task.terminationStatus != 0 {
   throw ShellError(
    terminationStatus: task.terminationStatus,
    errorData: errorData,
    inputData: inputData,
    outputData: outputData
   )
  }
  return outputData
 }
}

@discardableResult
public func output(
 _ command: CommandName,
 with arguments: String...,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> String {
 try output(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

@discardableResult
public func output(
 _ command: CommandName,
 _ arguments: some Sequence<String>,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> String {
 try output(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

@discardableResult
public func outputData(
 _ command: CommandName,
 with arguments: String...,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> Data {
 try outputData(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

@discardableResult
public func outputData(
 _ command: CommandName,
 _ arguments: some Sequence<String>,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> Data {
 try outputData(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

public extension Process {
 @inline(__always)
 var shell: String { environment?["SHELL"] ?? "/bin/sh" }
 @inline(__always)
 convenience init(_ command: String, args: some Sequence<String>) {
  self.init()
  self.executableURL = URL(fileURLWithPath: self.shell)
  self.arguments = ["-c", command.appending(arguments: args)]
 }
}

@inline(__always) public func process(
 command: String,
 _ args: some Sequence<String>
) throws {
 let process = Process(command, args: args)

 try process.run()
 process.waitUntilExit()

 let status = process.terminationStatus
 if status != 0 { throw _POSIXError.termination(status) }
}

@inline(__always)
public func process(
 _ command: CommandName, with args: some Sequence<String>
) throws {
 try process(command: command.rawValue, args)
}

@inline(__always)
public func process(
 _ command: CommandName, with args: String...
) throws {
 try process(command: command.rawValue, args)
}
#endif

private extension String {
 func appending(argument: String) -> String {
  "\(self) \"\(argument)\""
 }

 func appending(arguments: some Sequence<String>) -> String {
  self.appending(argument: arguments.joined(separator: "\" \""))
 }

 mutating func append(argument: String) {
  self = self.appending(argument: argument)
 }

 mutating func append(arguments: some Sequence<String>) {
  self = self.appending(arguments: arguments)
 }
}

#if os(WASI) || os(Windows)
@inlinable public func exit(_ error: some Error) -> Never {
 if let error = error as? ShellError {
  exit(error.terminationStatus, error.localizedDescription)
 } else if let error = error as? _POSIXError {
  Foundation.exit(error.status)
 }
 exit(Int32(error._code), error.message)
}
#else
@inlinable public func exit(_ error: some Error) -> Never {
 if let error = error as? ShellError {
  exit(error.terminationStatus, error.message)
 } else if let error = error as? _POSIXError {
  Foundation.exit(error.status)
 }

 #if os(macOS) || os(iOS)
 if #available(macOS 11.3, iOS 14.5, *) {
  let error = error as NSError
  if let posix = (error.underlyingErrors.first as? Foundation.POSIXError) {
   exit(posix.code.rawValue, error.localizedDescription)
  }
 }
 #endif
 exit(Int32(error._code), error.message)
}
#endif

/// Exits the process with either `help` variable, error, or optional reason
@inlinable public func exit(_ status: Int32 = 0, _ reason: Any) -> Never {
 if let reason = String(describing: reason).wrapped {
  if status == 0 {
   echo(reason, color: .green)
  } else if status > 0 {
   let error = status == 1
   if let spaceIndex =
    reason.firstIndex(where: { $0 == .space }),
    reason[reason.startIndex ..< spaceIndex].lowercased().hasPrefix("error") {
    echo(reason[spaceIndex ..< reason.endIndex], color: error ? .red : .yellow)
   } else {
    echo(reason, color: error ? .red : .yellow)
   }

  } else {
   print(reason)
  }
 }
 return Foundation.exit(status)
}

#if os(macOS)
import class AppKit.NSWorkspace
#elseif os(iOS)
import class UIKit.UIApplication
#endif
public func open(_ url: URL) {
 #if os(macOS)
 NSWorkspace.shared.open(url)
 #elseif os(iOS)
 if UIApplication.shared.canOpenURL(url) {
  UIApplication.shared.open(url, options: .empty, completionHandler: nil)
 } else {
  fatalError("Unsupported url: \(url)")
 }
 #else
 fatalError("Operating system not supported")
 #endif
}

public extension Data {
 init(curl path: String) throws {
  self = try outputData(.curl, with: "-s", path)
 }
}
