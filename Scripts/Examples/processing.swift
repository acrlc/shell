#!/usr/bin/env swift-shell
import Shell // @git/codeAcrylic/shell

let string = try output(.cat, with: "file.txt.input")
print("\nOutput:", string)

let data = try outputData(.cat, with: "file.txt.input")
print("Decoded:", String(data: data, encoding: .utf8) ?? "corrupt")
