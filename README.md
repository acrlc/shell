
#### Library designed to handle command line inputs and output
#### Examples
`process`, `output`, and `outputData`
```swift
// run process, throwing an error if theres an error code
try process(.git, with: "clone", "https://")

// read the output of a command
let string = try output(.cat, with: "file.input")
print("out:", string)

// read the data output of a command
let data = try outputData(.cat, with: "file.input")
print("decoded:", String(data: data, encoding: .utf8) ?? "corrupt")
```
`exit`
```swift
// print the string before exiting
exit(2, "empty input") // error: empty input
// print an error description before exiting
exit(error)
```
