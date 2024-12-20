#!/usr/bin/env swift-shell
import Shell // ..

/**
 Perform a command on every folder with intonation
 #### Features
  - Performs commands on folders within the current directory
  ```sh
  folders ls . # list the files in the folder
  ```
  - `{}` is a special string that's replaced with the folder name
  ```sh
  folders echo hello\ {}! # print the name of the folder
  ```
  - The `t` or `tag` option will limit the scope to folders with the set tag
  ```sh
  folders -t green echo {} # print the name of the folder if tagged green
  ```
 >note: this feature is macOS only
 */
@main enum Folders {
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

  func perform(_ folder: Folder) throws {
   folder.set()

   try process(
    command: command,
    arguments.contains(where: { $0.contains("{}") }) ?
     arguments.map { $0.replacingOccurrences(of: "{}", with: folder.name) } :
     arguments
   )
  }

  do {
   #if os(macOS)
   switch (tag, excludeTag) {
   case let (.some(tag), .none):
    for subfolder in folder.subfolders {
     guard let folderTags =
      try subfolder[.tagNames]?.map({ $0.lowercased() }),
      folderTags.contains(tag.lowercased()) else { continue }

     try perform(subfolder)
    }
   case let (.none, .some(excludeTag)):
    for subfolder in folder.subfolders {
     guard let folderTags =
      try subfolder[.tagNames]?.map({ $0.lowercased() }),
      !folderTags.contains(excludeTag.lowercased()) else { continue }

     try perform(subfolder)
    }
   case let (.some(tag), .some(excludeTag)):
    for subfolder in folder.subfolders {
     guard let folderTags =
      try subfolder[.tagNames]?.map({ $0.lowercased() }),
      !folderTags.contains(excludeTag.lowercased()), folderTags.contains(tag.lowercased()) else { continue }

     try perform(subfolder)
    }
   case (.none, .none):
    for subfolder in folder.subfolders {
     try perform(subfolder)
    }
   }

   #else
   for subfolder in folder.subfolders {
    try perform(subfolder)
   }
   #endif

  } catch {
   exit(error)
  }
 }
}

extension Folders {
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
