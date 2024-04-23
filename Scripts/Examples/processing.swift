#!/usr/bin/env swift-shell
import Shell // ../..

/// Note: must be in file directory to reference the input file
let string = try processOutput(.cat, with: "file.txt.input")
print("out:", string)

let data = try processData(.cat, with: "file.txt.input")
print("decoded:", String(data: data, encoding: .utf8) ?? "corrupt")
