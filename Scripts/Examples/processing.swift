#!/usr/bin/env swift-shell
import Shell // $main/shell

try process("cat", ["file.txt.input"])

let string = try execute("cat", ["file.txt.input"])
print("\nOutput:", string)

let data = try executeData("cat", ["file.txt.input"])
print("Decoded:", String(data: data, encoding: .utf8) ?? "corrupt")
