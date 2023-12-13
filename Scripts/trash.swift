#!/usr/bin/env swift-shell
import Shell // ..

/// Sends files to the trash using Finder
/// `trash <f, force> <[path]>`
/// # Caveats
/// - will not prompt when using the `force` flag
@main enum Trash {
 /// Optional flag to permanently delete files
 static var force: Bool = false
 /// Files to trash or delete
 static var inputs = CommandLine.arguments[1...]

 static func main() {
  parse()
  guard self.inputs.notEmpty else {
   print("input <\("path", style: .boldDim)> required")
   exit(1)
  }

  do {
   if self.force {
    try process(.rm, with: ["-frd"] + self.inputs)
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
 static func parse() {
  if let first = inputs.first, first.hasPrefix("-") {
   let option = first.drop(while: { $0 == "-" })
   if option == "f" || option == "force" {
    force = true
    inputs.removeFirst()
   }
  }
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
