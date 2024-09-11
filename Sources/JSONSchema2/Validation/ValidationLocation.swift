public struct ValidationLocation {
  var keywordLocation: JSONPointer
  var instanceLocation: JSONPointer
  /// Required if keyworkLocation is a ref or dynamic ref
  var absoluteKeywordLocation: JSONPointer?

  init() {
    keywordLocation = .init()
    instanceLocation = .init()
  }
}
