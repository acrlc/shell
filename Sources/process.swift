@_exported import Core
@_exported import Extensions
#if !os(WASI)
// There is no FileManager built into the Swift WASM runtime
// https://github.com/WebAssembly/wasi-filesystem
@_exported import Paths
#endif
@_exported import struct Components.Regex
@_exported import Foundation

private extension FileHandle {
 var isStandard: Bool {
  self === FileHandle.standardOutput ||
   self === FileHandle.standardError ||
   self === FileHandle.standardInput
 }
}

#if os(macOS) || os(Linux)
@discardableResult
public func processOutput(
 command: String, _ args: some Sequence<String> = [],
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> String {
 task.executableURL = URL(fileURLWithPath: Process.shell)
 task.arguments = ["-c", command.appending(arguments: args)]
 // Because FileHandle's readabilityHandler might be called from a
 // different queue from the calling queue, avoid a data race by
 // protecting reads and writes to outputData and errorData on
 // a single dispatch queue.
 let inputQueue = DispatchQueue(label: "shell-input-queue")
 let outputQueue = DispatchQueue(label: "shell-output-queue")

 var dataIn = Data()
 var dataOut = Data()
 var errorData = Data()

 let inputPipe = Pipe()
 task.standardInput = inputPipe

 let outputPipe = pipe
 task.standardOutput = outputPipe

 let errorPipe = Pipe()
 task.standardError = errorPipe

 inputPipe.fileHandleForReading.readabilityHandler = { handler in
  let data = handler.availableData
  inputQueue.async {
   dataIn.append(data)
   inputHandle?.write(data)
  }
 }

 if !silent {
  outputPipe.fileHandleForReading.readabilityHandler = { handler in
   let data = handler.availableData
   outputQueue.async {
    dataOut.append(data)
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

 try task.run()
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

  outputPipe.fileHandleForReading.readabilityHandler = nil
  errorPipe.fileHandleForReading.readabilityHandler = nil
 }
 // Block until all writes have occurred to outputData and errorData,
 // and then read the data back out.
 return try outputQueue.sync {
  if task.terminationStatus != 0 {
   throw ShellError(
    terminationStatus: task.terminationStatus,
    errorData: errorData,
    inputData: dataIn,
    outputData: dataOut
   )
  }
  return dataOut.shellOutput()
 }
}

@discardableResult
public func processData(
 command: String, _ args: some Sequence<String> = [],
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> Data {
 task.executableURL = URL(fileURLWithPath: Process.shell)
 task.arguments = ["-c", command.appending(arguments: args)]
 let inputQueue = DispatchQueue(label: "shell-input-queue")
 let outputQueue = DispatchQueue(label: "shell-output-queue")

 var dataIn = Data()
 var dataOut = Data()
 var errorData = Data()

 let inputPipe = Pipe()
 task.standardInput = inputPipe

 let outputPipe = pipe
 task.standardOutput = outputPipe

 let errorPipe = Pipe()
 task.standardError = errorPipe

 inputPipe.fileHandleForReading.readabilityHandler = { handler in
  let data = handler.availableData
  inputQueue.async {
   dataIn.append(data)
   inputHandle?.write(data)
  }
 }

 if !silent {
  outputPipe.fileHandleForReading.readabilityHandler = { handler in
   let data = handler.availableData
   outputQueue.async {
    dataOut.append(data)
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

 try task.run()
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

  outputPipe.fileHandleForReading.readabilityHandler = nil
  errorPipe.fileHandleForReading.readabilityHandler = nil
 }
 return try outputQueue.sync {
  if task.terminationStatus != 0 {
   throw ShellError(
    terminationStatus: task.terminationStatus,
    errorData: errorData,
    inputData: dataIn,
    outputData: dataOut
   )
  }
  return dataOut
 }
}

@discardableResult
public func processOutput(
 _ command: CommandName, with arguments: String...,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> String {
 try processOutput(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

@discardableResult
public func processOutput(
 _ command: CommandName, with arguments: some Sequence<String>,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> String {
 try processOutput(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

@discardableResult
public func processData(
 _ command: CommandName, with arguments: String...,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> Data {
 try processData(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

@discardableResult
public func processData(
 _ command: CommandName, _ arguments: some Sequence<String>,
 inputHandle: FileHandle? = nil,
 outputHandle: FileHandle? = nil,
 errorHandle: FileHandle? = .nullDevice,
 process task: Process = Process(), pipe: Pipe = Pipe(),
 silent: Bool = false
) throws -> Data {
 try processData(
  command: command.rawValue, arguments,
  inputHandle: inputHandle,
  outputHandle: outputHandle,
  errorHandle: errorHandle, process: task, pipe: pipe, silent: silent
 )
}

public extension Process {
 @inline(__always)
 static var shell: String { Shell.env["SHELL"] ?? "/bin/dash" }
 @inline(__always)
 convenience init(_ command: String, args: some Sequence<String>) {
  self.init()
  executableURL = URL(fileURLWithPath: Process.shell)
  arguments = ["-c", command.appending(arguments: args)]
 }
}

@inline(__always)
public func process(
 command: String, _ args: some Sequence<String> = []
) throws {
 let process = Process(command, args: args)

 try process.run()
 process.waitUntilExit()

 let status = process.terminationStatus
 if status != 0 { throw _POSIXError.termination(status) }
}

@inline(__always)
public func process(
 command: String, _ args: some Sequence<String> = [], process: Process
) throws {
 process.executableURL = URL(fileURLWithPath: Process.shell)
 process.arguments = ["-c", command.appending(arguments: args)]
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
 _ command: CommandName,
 with args: some Sequence<String>,
 process linkedProcess: Process
) throws {
 try process(command: command.rawValue, args, process: linkedProcess)
}

@inline(__always)
public func process(
 _ command: CommandName, with args: String...
) throws {
 try process(command: command.rawValue, args)
}

@inline(__always)
public func process(
 _ command: CommandName,
 with args: String...,
 process linkedProcess: Process
) throws {
 try process(command: command.rawValue, args, process: linkedProcess)
}

public extension Data {
 init(curl path: String) throws {
  self = try processData(.curl, with: "-s", path)
 }
}
#endif

private extension String {
 func appending(argument: String) -> String {
  "\(self) \"\(argument)\""
 }

 func appending(arguments: some Sequence<String>) -> String {
  appending(argument: arguments.joined(separator: "\" \""))
 }

 mutating func append(argument: String) {
  self = appending(argument: argument)
 }

 mutating func append(arguments: some Sequence<String>) {
  self = appending(arguments: arguments)
 }
}

#if os(WASI) || os(Windows)
@inlinable public func exit(_ error: some Error) -> Never {
 if let error = error as? ShellError {
  exit(error.terminationStatus, error.localizedDescription)
 }
 #if !os(WASI)
 if let error = error as? _POSIXError { Foundation.exit(error.status) }
 #endif
 exit(Int32(error._code), error.message)
}
#else
@inlinable public func exit(_ error: some Error) -> Never {
 if let error = error as? ShellError {
  exit(error.terminationStatus, error.message)
 }
 #if !os(WASI)
 if let error = error as? _POSIXError {
  Foundation.exit(error.status)
 }
 #endif
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

/// Exits the process with optional error or description.
@inlinable public func exit(_ status: Int32 = 0, _ reason: Any) -> Never {
 if let reason = String(describing: reason).wrapped {
  if status == 0 {
   echo(reason, color: .green)
  } else if status > 0 {
   let error = status == 1
   if let spaceIndex =
    reason.firstIndex(where: { $0 == .space }),
    reason[reason.startIndex ..< spaceIndex].lowercased().hasPrefix("error") {
    echo(
     reason[spaceIndex ..< reason.endIndex].drop(while: { $0.isWhitespace }),
     color: error ? .red : .yellow
    )
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
