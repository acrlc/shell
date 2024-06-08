#!/usr/bin/env swift-shell
import Shell // ..

/// Sends files to the trash using Finder
/// `trash <options> <paths>`
///
/// - Parameters:
///   - options: A set of options to pass to `rm`, instead of the trash bin.
///   - paths: The relative paths to remove or move to the trash bin
///
/// # Caveats
/// - will not prompt when using some options (redirects to `rm` command)
/// - will not prompt for password when emptying trash, which requires `sudo`
@main
enum Trash {
 /// Options to pass to `rm` if necessary or `e`/`empty` to empty.
 static var options: [String] = .empty
 /// Files to trash or delete
 static var inputs = CommandLine.arguments[1...]

 static func main() throws {
  try parse()
  guard inputs.notEmpty else {
   exitNoInput()
  }

  do {
   if let options = options.wrapped {
    try process(.rm, with: options + inputs)
   } else {
    let urls = try inputs.compactMap {
     let url = URL(fileURLWithPath: $0)
     do {
      if try url.checkResourceIsReachable() { return url }
     } catch {
      throw Error.fileIsMissing(url)
     }
     return nil
    }

    /// adapted from https://github.com/aerobounce/trash.swift
    let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
    let event = NSAppleEventDescriptor(
     eventClass: kAECoreSuite,
     eventID: AEEventID(kAEDelete),
     targetDescriptor: target,
     returnID: AEReturnID(kAutoGenerateReturnID),
     transactionID: AETransactionID(kAnyTransactionID)
    )

    let listDescriptor = NSAppleEventDescriptor(listDescriptor: ())
    for (offset, url) in urls.enumerated() {
     /// UTF-8 encoded full path with native path separators
     let nativePath = try NSAppleEventDescriptor(
      descriptorType: typeFileURL,
      data: url.absoluteString.data(using: .utf8)
     ).throwing()

     // note: must add an additional offset to the list
     listDescriptor.insert(nativePath, at: offset + 1)
    }

    event.setParam(listDescriptor, forKeyword: keyDirectObject)

    do {
     try event.sendEvent(
      options: .noReply,
      timeout: TimeInterval(kAEDefaultTimeout)
     )
    } catch let error as NSError {
     if case -600 = error.code {
      throw Error.finderNotRunning
     } else {
      throw error
     }
    }
   }
  } catch {
   exit(error)
  }
 }
}

extension Trash {
 static func parse() throws {
  guard let first = inputs.first else {
   exitNoInput()
  }

  guard first.hasPrefix("-") else {
   return
  }

  if ["e", "empty"].contains(first.drop(while: { $0 == "-" })) {
   do {
    let home = Folder.home
    try home.subfolder(at: ".Trash").delete()
    try home.createSubfolderIfNeeded(at: ".Trash")
   } catch let error as PathError {
    switch error.reason {
    case .missing: break
    default: exit(error)
    }
   }
   exit(0)
  } else {
   while let first = inputs.first, first.hasPrefix("-") {
    options.append(inputs.removeFirst())
   }
  }
 }

 static func exitNoInput() -> Never {
  print("input <\("paths", style: .boldDim)> required")
  return exit(1)
 }

 enum Error: LocalizedError, CustomStringConvertible {
  case finderNotRunning, fileIsMissing(URL)
  var _code: Int {
   switch self {
   case .finderNotRunning: 1
   case .fileIsMissing: 2
   }
  }

  var errorDescription: String? {
   switch self {
   case .finderNotRunning: "finder isn't running"
   case .fileIsMissing(let url): "path missing for '\(url.relativePath)' "
   }
  }
 }
}
