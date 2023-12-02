@_exported import Chalk

public extension String {
 var resolvedPath: Self {
  #if os(WASI)
  (URL(string: self) ?? URL(fileURLWithPath: self)).path
  #else
  (URL(string: self) ??
   URL(fileURLWithPath: self).resolvingSymlinksInPath()).path
  #endif
 }
}

public extension String {
 var escapingSpaces: String {
  replacingOccurrences(of: " ", with: #"\ "#)
 }

 var escapingParentheses: String {
  replacingOccurrences(of: "(", with: #"\("#)
   .replacingOccurrences(of: ")", with: #"\)"#)
 }

 var escapingAmpersand: String {
  replacingOccurrences(of: #"&"#, with: #"\&"#)
 }

 var escapingAll: String {
  self.escapingSpaces.escapingParentheses.escapingAmpersand
 }

 var fixingDoubleSlashes: String {
  replacingOccurrences(of: #"\\"#, with: "\\")
 }

 var doubleQuoted: String { "\"\"\(self)\"\"" }
 var quoted: String { "\"\(self)\"" }

 func wrap(to limit: Int) -> Self {
  guard self.count > limit else { return self }
  let substring = self[
   self.startIndex ..< self.index(self.startIndex, offsetBy: limit - 1)
  ]
  return String(substring) + "…"
 }

 func fill(to limit: Int, with character: Character) -> Self {
  guard self.count > limit else { return self }
  return self + String(repeating: character, count: limit - self.count)
 }

 @inlinable
 func contains(regex pattern: KeyPath<Regex, String>) -> Bool {
  range(
   of: Self.regex[keyPath: pattern], options: [.regularExpression]
  ) != nil
 }

 @inlinable
 func matches(regex pattern: KeyPath<Regex, String>) -> Bool {
  guard let matchingRange = range(
   of: Self.regex[keyPath: pattern], options: [.regularExpression]
  ) else { return false }
  let range = self.range
  return range == matchingRange || range.overlaps(matchingRange)
 }

 @inline(__always)
 // https://leetcode.com/problems/wildcard-matching/solutions/272598/Swift-solution/
 func contains(wildcard: String) -> Bool {
  let p = wildcard
  let m = count
  let n = p.count
  var dp = [[Bool]](repeating: [Bool](repeating: false, count: n + 1), count: m + 1)
  dp[0][0] = true
  for i in 0 ... m {
   for j in 1 ... n {
    if p[p.index(p.startIndex, offsetBy: j - 1)] == "*" {
     dp[i][j] = dp[i][j - 1] || (i > 0 && dp[i - 1][j])
    } else {
     dp[i][j] = i > 0 && dp[i - 1][j - 1] &&
      (p[p.index(p.startIndex, offsetBy: j - 1)] == "?" ||
       p[p.index(p.startIndex, offsetBy: j - 1)] ==
       self[index(startIndex, offsetBy: i - 1)])
    }
   }
  }
  return dp[m][n]
 }

 @inline(__always)
 func match(wildcard: String) -> Substring? {
  var i = startIndex
  var j = wildcard.startIndex
  var start: Index?
  var match = startIndex { didSet { if start == nil { start = match } } }
  var star = wildcard.endIndex

  while i != endIndex {
   if j < wildcard.endIndex, self[i] == wildcard[j] || wildcard[j] == "?" {
    i = index(after: i)
    j = wildcard.index(after: j)
   } else if j != wildcard.endIndex, wildcard[j] == "*" {
    star = j
    match = i
    j = index(after: j)
   } else if star != wildcard.endIndex {
    j = index(after: star)
    match = index(after: match)
    i = match
   } else {
    return nil
   }
  }

  if let start { return self[start ..< match] }
  else { return nil }
 }
}

public extension String {
 @_transparent
 func applying(
  color: Color? = nil,
  background: Color? = nil,
  style: Style? = nil
 ) -> String {
  switch (color, background, style) {
  case (.some(let color), nil, nil):
   return "\(self, color: color)"
  case (.some(let color), nil, .some(let style)):
   return "\(self, color: color, style: style)"
  case (nil, nil, .some(let style)): return "\(self, style: style)"
  case (nil, .some(let background), .some(let style)):
   return "\(self, background: background, style: style)"
  case (nil, .some(let background), nil):
   return "\(self, background: background)"
  case (.some(let color), .some(let background), nil):
   return "\(self, color: color, background: background)"
  case (.some(let color), .some(let background), .some(let style)):
   return "\(self, color: color, background: background, style: style)"
  default: return self
  }
 }
}

public extension Style {
 static let boldDim: Self = [.bold, .dim]
}

@_transparent
public func echo(
 _ items: Any...,
 color: Color? = nil, background: Color? = nil, style: Style? = nil,
 separator: String = " ", terminator: String = "\n"
) {
 print(
  items.map { "\($0)" }
   .joined(separator: separator)
   .applying(color: color, background: background, style: style),
  terminator: terminator
 )
}

public extension Substring {
 var expandingVariables: String {
  guard self.contains("$") else { return String(self) }
  var cursor: String.Index = self.startIndex
  var parts: [String] = .empty
  while cursor < self.endIndex {
   let character = self[cursor]

   func expandedVariable(_ substring: Self) -> String? {
    Shell.env[String(substring)] ??
     Shell.env[String(substring.uppercased())] ??
     Shell.env[String(substring.lowercased())]
   }

   if character == "$" {
    cursor = self.index(after: cursor)
    if cursor != self.endIndex {
     let substring = self[cursor ..< self.endIndex]
     if let partition =
      substring.firstIndex(where: { $0 == "/" || $0.isWhitespace }) {
      defer { cursor = partition }
      let substring = substring[cursor ..< partition]
      if var expansion = expandedVariable(substring) {
       while expansion.hasSuffix("/") { expansion.removeLast() }
       parts.append(expansion)
       continue
      } else {
       parts.append(String(character) + String(substring))
      }
     } else if substring.allSatisfy({ $0 != "/" || !$0.isWhitespace }) {
      cursor = self.endIndex
      if var expansion = expandedVariable(substring) {
       while expansion.hasSuffix("/") { expansion.removeLast() }
       parts.append(expansion)
      } else {
       parts.append(String(character) + String(substring))
      }
      break
     }
    } else {
     parts.append(String(character))
    }
   } else {
    cursor = self.index(after: cursor)
    parts.append(String(character))
   }
  }
  return parts.joined()
 }
}

public extension String {
 var expandingVariables: Self {
  guard self.contains("$") else { return self }
  var cursor: String.Index = self.startIndex
  var parts: [String] = .empty
  while cursor < self.endIndex {
   let character = self[cursor]

   func expandedVariable(_ substring: Substring) -> String? {
    Shell.env[String(substring)] ??
     Shell.env[String(substring.uppercased())] ??
     Shell.env[String(substring.lowercased())]
   }

   if character == "$" {
    cursor = self.index(after: cursor)
    if cursor != self.endIndex {
     let substring = self[cursor ..< self.endIndex]
     if let partition =
      substring.firstIndex(where: { $0 == "/" || $0.isWhitespace }) {
      defer { cursor = partition }
      let substring = substring[cursor ..< partition]
      if var expansion = expandedVariable(substring) {
       while expansion.hasSuffix("/") { expansion.removeLast() }
       parts.append(expansion)
       continue
      } else {
       parts.append(String(character) + String(substring))
      }
     } else if substring.allSatisfy({ $0 != "/" || !$0.isWhitespace }) {
      cursor = self.endIndex
      if var expansion = expandedVariable(substring) {
       while expansion.hasSuffix("/") { expansion.removeLast() }
       parts.append(expansion)
      } else {
       parts.append(String(character) + String(substring))
      }
      break
     }
    } else {
     parts.append(String(character))
    }
   } else {
    cursor = self.index(after: cursor)
    parts.append(String(character))
   }
  }
  return parts.joined()
 }
}
