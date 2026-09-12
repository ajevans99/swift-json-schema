import OrderedJSON

extension JSONValue {
  /// JSON Schema's integer type is mathematical, independent of JSON number storage.
  package var isMathematicalInteger: Bool {
    numberLiteral?.isInteger == true
  }

  /// An exactly representable Swift integer, without changing the stored JSON value.
  package var exactInteger: Int? {
    integer
  }
}
