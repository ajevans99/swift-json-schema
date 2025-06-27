extension JSONValue {
  /// Mutates `self` by merging in values from `other`.
  /// - Arrays are concatenated.
  /// - Objects are merged recursively.
  /// - Scalars are preserved unless `self` is `.null`.
  public mutating func merge(_ other: JSONValue) {
    switch (self, other) {
    case (.object(var lhsDict), .object(let rhsDict)):
      for (key, rhsValue) in rhsDict {
        if let lhsValue = lhsDict[key] {
          var mergedValue = lhsValue
          mergedValue.merge(rhsValue)
          lhsDict[key] = mergedValue
        } else {
          lhsDict[key] = rhsValue
        }
      }
      self = .object(lhsDict)

    case (.array(let lhsArray), .array(let rhsArray)):
      self = .array(lhsArray + rhsArray)

    case (.null, let rhs):  // If self is null, adopt other
      self = rhs

    default:
      // Keep existing self by default (no overwrite)
      break
    }
  }
}
