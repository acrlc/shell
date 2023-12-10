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

public extension CommandLine {
 static var usage: String?
}
