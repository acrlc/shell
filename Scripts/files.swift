#!/usr/bin/env swift-shell
import Shell // ..

/**
 Perform a command on every file with intonation
 */
@main enum Files {
 static let folder = Folder.current
 #if os(macOS)
 static var tag: String?
 static var excludeTag: String?
 #endif

 static var arguments = CommandLine.arguments[1...].map { $0 }

 static func main() {
  #if os(macOS)
  parse()
  #endif

  guard arguments.notEmpty else { exit(1, "missing input <command>") }
  let command = arguments.removeFirst()

  func perform(_ file: File) throws {
   folder.set()

   try process(
    command: command,
    arguments.contains(where: { $0.contains("{}") }) ?
     arguments.map { $0.replacingOccurrences(of: "{}", with: file.name) } :
     arguments
   )
  }

  do {
   #if os(macOS)
   switch (tag, excludeTag) {
   case let (.some(tag), .none):
    for file in folder.files {
     guard let fileTags =
      try file[.tagNames]?.map({ $0.lowercased() }),
      fileTags.contains(tag.lowercased()) else { continue }

     try perform(file)
    }
   case let (.none, .some(excludeTag)):
    for file in folder.files {
     if let fileTags = try file[.tagNames]?.map({ $0.lowercased() }) {
      guard !fileTags.contains(excludeTag.lowercased()) else { continue }
     }
     try perform(file)
    }
   case let (.some(tag), .some(excludeTag)):
    for file in folder.files {
     guard let fileTags =
      try file[.tagNames]?.map({ $0.lowercased() }),
      !fileTags.contains(excludeTag.lowercased()), fileTags.contains(tag.lowercased()) else { continue }

     try perform(file)
    }
   case (.none, .none):
    for file in folder.files {
     try perform(file)
    }
   }

   #else
   for file in folder.files {
    try perform(file)
   }
   #endif

  } catch {
   exit(error)
  }
 }
}

extension Files {
 static func parse() {
  while let first = arguments.first, first.hasPrefix("-") {
   let option = first.drop(while: { $0 == "-" })
   switch option {
   case "t", "tag":
    arguments.removeFirst()
    guard let input = arguments.first?.wrapped else {
     exit(1, "option -t, --tag must include a tag name")
    }
    tag = input
    arguments.removeFirst()
   case "excludeTag":
    arguments.removeFirst()
    guard let input = arguments.first?.wrapped else {
     exit(1, "option --excludeTag must include a tag name")
    }
    excludeTag = input
    arguments.removeFirst()
   default: break
   }
  }
 }
}
