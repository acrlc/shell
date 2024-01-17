#!/usr/bin/env swift-shell
import Shell // ..

/**
 # git
 an overlay for the git command that introduces *simplification*
 #### Features
 - converts user/repo to github addresses
 - adds subcommand `initialize` to initialize a source with a remote url
 - adds subcommand `source` to add a remote to an initialized repository
 #### Usage
 ```sh
 # clone using shorthand user/repo
 git clone <user/repo>
 # clone with shorthand based on folder, assuming it's the user's name
 git clone <repo>
 examples:
  git clone user/repo
  git clone repo
 subcommands: (will prompt by default if some or all inputs are missing)
 # initialize a repository with a remote url
 git initialize <option> <repository> <branch>
 option:
  -m, --message <input>: initial commit message (default is 'initial')
 example: git initialize -m "starting" user/repo default
 # source a remote using a local repository and branch
 git source <repository> <branch>
 example: git source user/repo default
 ```
 #### Caveats
 - using `clone` assumes the domain github when using the shorthand parameter
 - could support `clone` option or further inference to find a domain name
 - subcommands exit but don't resolve issues with `.git` and `.gitignore`
 */
@main enum Git {
 static let folder = Folder.current
 // note: when dropping the first the index must be remapped with an array
 // to support normal subscripting
 static var arguments = CommandLine.arguments[1...].map { $0 }
 static let subcommand = arguments.first

 static func main() {
  do {
   if subcommand == "clone" {
    // TODO: make safe for complex arguments within this scope
    // and read parent folders names such as 'github' or 'huggingface' to
    // so they can be used for the shorthand domain
    if !arguments.contains(where: { $0.matches(regex: \.url) }) {
     let lastIndex = arguments.endIndex - 1
     let path = arguments[lastIndex]
     // note: it's possible to assume the domain based on the previous path
     // replace with shorthand url
     // TODO: isolate paths which could be limited here
     if path.contains("/") {
      arguments[lastIndex] = "https://github.com/\(path)"
     } else {
      // replace with folder based url
      let user = Folder.current.name
      arguments[lastIndex] = "https://github.com/\(user)/\(path)"
     }
    }
   } else if subcommand == "initialize" {
    guard !folder.containsSubfolder(named: ".git") else {
     print("current folder appears to be a repository")
     print(
      "delete .git or use 'git source' to add a remote to your local repo"
     )
     exit(2)
    }

    assertIgnored()
    checkLicensed()
    arguments.removeFirst()

    var message: String?
    if let first = arguments.first, first.hasPrefix("-") {
     let option = first.drop(while: { $0 == "-" })
     if option == "m" || option == "message" {
      arguments.removeFirst()
      guard let input = arguments.first?.wrapped else {
       exit(1, "option -m, --message must include an input")
      }
      message = input
      arguments.removeFirst()
     } else {
      exit(2, "unknown flag at \(first)")
     }
    } else {
     print("Enter initial commit message(default, initial): ", terminator: .empty)
     message = readLine()?.wrapped
    }

    try process(.git, with: "init")
    try process(.git, with: "add", "--all")
    try process(.git, with: "commit", "-m", message ?? "initial")

    let remote = getRemote(arguments.first)
    let branch = arguments.count > 1 ? arguments[1] : getBranch() ?? "main"

    try process(.git, with: "branch", "-M", branch)
    try process(.git, with: "remote", "add", "origin", remote)

    request()
    try process(.git, with: "push", "-u", "origin", branch)

    exit(0)
   } else if subcommand == "source" {
    guard folder.containsSubfolder(named: ".git") else {
     print("current folder isn't a repository")
     print("use 'git init && git source' or 'git initialize' to add remote")
     exit(1)
    }

    assertIgnored()
    checkLicensed()
    arguments.removeFirst()

    let remote = getRemote(arguments.first)
    let branch = arguments.count > 1 ? arguments[1] : getBranch() ?? "main"

    try process(.git, with: "remote", "add", "origin", remote)
    try process(.git, with: "branch", "-M", branch)

    request()
    try process(.git, with: "push", "-u", "origin", branch)

    exit(0)
   }

   try process(.git, with: arguments)
  }
  catch let error as _POSIXError { exit(error.status) }
  catch { fatalError() }
 }
}

extension Git {
 static func assertIgnored() {
  guard
   let ignoreFile = try? folder.file(named: ".gitignore"),
   let data = try? ignoreFile.read(), !data.isEmpty else {
   exit(2, "add a non empty .gitignore to this current folder to start")
  }
 }

 static func readContinue() {
  if let input = readLine()?.lowercased() {
   switch input {
   case "y", "yes": break
   case "n", "no": fallthrough
   default: exit(0)
   }
  }
 }

 static func checkLicensed() {
  guard let licenseFile =
   folder.files.first(where: {
    $0.nameExcludingExtension.lowercased() == "license"
   }), let data = try? licenseFile.read(), !data.isEmpty else {
   print("Continue without a license? [y/n]: ", terminator: .empty)
   return readContinue()
  }
 }

 static func getRemote(_ optional: String?) -> String {
  var remote: String! = optional
  var retry = false
  while remote == nil {
   print("Enter remote user/repo or address: ", terminator: .empty)

   if let input = readLine()?.wrapped { remote = input }
   else {
    Shell.clearScrollback()
    if !retry { print("Please, try again", terminator: "\n"); retry = true }
   }
  }

  return remote.matches(regex: \.url) ? remote : "https://github.com/\(remote!)"
 }

 static func getBranch() -> String? {
  print("Enter optional branch (default, main): ", terminator: .empty)
  return readLine()?.wrapped
 }

 static func request() {
  print("Push this commit to remote? [y/n]: ", terminator: .empty)
  readContinue()
 }
}
