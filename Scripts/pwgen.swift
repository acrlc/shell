#!/usr/bin/env swift-shell
import Shell // ..

let args = CommandLine.arguments[1...]

CommandLine.usage =
 """
 Prints out a random string of numbers and letters.
 \("usage", style: .bold): \
 pwgen <\("length", style: .boldDim)> <\("count", style: .boldDim)?>
 """

guard args.notEmpty else {
 print("\n\(CommandLine.usage!)\n")
 exit(2, "at least one argument must be entered (length)")
}

guard args[1].drop(while: { $0 == "-" }) != "help" else {
 print("\n\(CommandLine.usage!)\n")
 exit(0)
}

guard let length = Int(args[1]), length > 0 else {
 print("\n\(CommandLine.usage!)\n")
 exit(1, "invalid argument for length, must be an unsigned integer > 0")
}

var count: Int = 1
if args.count > 1 {
 guard let input = Int(args[2]), input > 0 else {
  exit(1, "invalid argument for count, must be an unsigned integer > 0")
 }
 count = input
}

let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
for _ in 0 ..< count {
 print(
  String((0 ..< length).map { _ in chars.randomElement()! }),
  terminator: .space
 )
}

print("\n", terminator: .empty)
