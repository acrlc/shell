// swift-tools-version:5.5
import PackageDescription

let package = Package(
 name: "Shell",
 platforms: [.macOS(.v10_15), .iOS(.v13)],
 products: [.library(name: "Shell", targets: ["Shell"])],
 dependencies: [
  .package(url: "https://github.com/acrlc/core.git", branch: "main"),
  .package(
   url: "https://github.com/acrlc/Chalk.git",
   branch: "add-default-color"
  ),
  .package(
   url: "https://github.com/swift-server/swift-service-lifecycle.git",
   from: "2.6.2"
  )
 ],
 targets: [
  .target(
   name: "Shell", dependencies: [
    .product(name: "Core", package: "core"),
    .product(name: "Extensions", package: "core"),
    .product(name: "Components", package: "core"),
    "Chalk",
    .product(name: "UnixSignals", package: "swift-service-lifecycle"),
   ],
   path: "Sources"
  )
 ]
)

#if !arch(wasm32)
package.dependencies.append(
 .package(url: "https://github.com/acrlc/paths.git", from: "0.1.0")
)
for target in package.targets {
 if target.name == "Shell" {
  target.dependencies += [
   .product(
    name: "Paths", package: "paths",
    condition: .when(platforms: [.macOS, .iOS, .linux, .windows])
   )
  ]
  break
 }
}
#endif
