#!/usr/bin/env swift-shell
import Shell // @git/codeAcrylic/shell

/// Note: must be in file directory to reference the input file
let string = try output(.cat, with: "file.txt.input")
print("\nOutput:", string)

let data = try outputData(.cat, with: "file.txt.input")
print("Decoded:", String(data: data, encoding: .utf8) ?? "corrupt")
