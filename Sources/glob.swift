#if canImport(Darwin)
import Darwin
private let globFunction = Darwin.glob
#elseif canImport(Glibc)
import Glibc
private let globFunction = Glibc.glob
#endif

#if os(macOS) || os(Linux) || os(Windows)
import Foundation
// Adapted from https://gist.github.com/efirestone/ce01ae109e08772647eb061b3bb387c3
public struct Glob {
 static func resolveGlob(_ pattern: String) -> [String] {
  let globCharset = CharacterSet(charactersIn: "*?[]")
  guard pattern.rangeOfCharacter(from: globCharset) != nil else {
   return [pattern]
  }

  return self.expandGlobstar(pattern: pattern)
   .reduce(into: [String]()) { paths, pattern in
    var globResult = glob_t()
    defer { globfree(&globResult) }

    if globFunction(pattern, GLOB_TILDE | GLOB_BRACE | GLOB_MARK, nil, &globResult) == 0 {
     paths.append(contentsOf: self.populateFiles(globResult: globResult))
    }
   }
   .unique()
   .sorted()
   .map { $0.absolutePathStandardized() }
 }

 // MARK: Private

 private static func expandGlobstar(pattern: String) -> [String] {
  guard pattern.contains("**") else {
   return [pattern]
  }

  var results = [String]()
  var parts = pattern.components(separatedBy: "**")
  let firstPart = parts.removeFirst()
  var lastPart = parts.joined(separator: "**")

  let fileManager = FileManager.default

  var directories: [String]

  let searchPath = firstPart.isEmpty ? fileManager.currentDirectoryPath : firstPart
  do {
   directories = try fileManager.subpathsOfDirectory(atPath: searchPath).compactMap { subpath in
    let fullPath = firstPart.bridge().appendingPathComponent(subpath)
    guard self.isDirectory(path: fullPath) else { return nil }
    return fullPath
   }
  } catch {
   directories = []
  }

  // Check the base directory for the glob star as well.
  directories.insert(firstPart, at: 0)

  // Include the globstar root directory ("dir/") in a pattern like "dir/**" or "dir/**/"
  if lastPart.isEmpty {
   results.append(firstPart)
   lastPart = "*"
  }

  for directory in directories {
   let partiallyResolvedPattern: String = {
    if directory.isEmpty {
     return lastPart.starts(with: "/") ? String(lastPart.dropFirst()) : lastPart
    } else {
     return directory.bridge().appendingPathComponent(lastPart)
    }
   }()
   results.append(contentsOf: self.expandGlobstar(pattern: partiallyResolvedPattern))
  }

  return results
 }

 private static func isDirectory(path: String) -> Bool {
  var isDirectoryBool = ObjCBool(false)
  let isDirectory = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectoryBool)
  return isDirectory && isDirectoryBool.boolValue
 }

 private static func populateFiles(globResult: glob_t) -> [String] {
  #if os(Linux)
  let matchCount = globResult.gl_pathc
  #else
  let matchCount = globResult.gl_matchc
  #endif
  return (0 ..< Int(matchCount)).compactMap { index in
   globResult.gl_pathv[index].flatMap { String(validatingUTF8: $0) }
  }
 }
}

extension String {
 func absolutePathStandardized() -> String {
  bridge().absolutePathRepresentation().bridge().standardizingPath
 }
}

public extension Array {
 func bridge() -> NSArray {
  self as NSArray
 }
}

public extension CharacterSet {
 func bridge() -> NSCharacterSet {
  self as NSCharacterSet
 }
}

public extension Dictionary {
 func bridge() -> NSDictionary {
  self as NSDictionary
 }
}

public extension NSString {
 func bridge() -> String {
  self as String
 }
}

public extension String {
 func bridge() -> NSString {
  self as NSString
 }
}

public extension NSString {
 /**
  Returns self represented as an absolute path.

  - parameter rootDirectory: Absolute parent path if not already an absolute path.
  */
 func absolutePathRepresentation(rootDirectory: String = FileManager.default.currentDirectoryPath) -> String {
  if isAbsolutePath { return self.bridge() }
  #if os(Linux)
  return NSURL(fileURLWithPath: NSURL.fileURL(withPathComponents: [rootDirectory, self.bridge()])!.path).standardizingPath!.path
  #else
  return NSString.path(withComponents: [rootDirectory, self.bridge()]).bridge().standardizingPath
  #endif
 }
}
#endif
