public struct ValidationLocation: Sendable, Codable, Equatable {
  var keywordLocation: JSONPointer
  var instanceLocation: JSONPointer
  /// Required if keyworkLocation is a ref or dynamic ref
  var absoluteKeywordLocation: JSONPointer?

  var isRoot: Bool { keywordLocation.isRoot }

  public init(keywordLocation: JSONPointer = .init(), instanceLocation: JSONPointer = .init()) {
    self.keywordLocation = keywordLocation
    self.instanceLocation = instanceLocation
  }
}
