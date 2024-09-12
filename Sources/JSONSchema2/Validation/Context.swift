/// Container for information used when validating a schema.
struct Context: Equatable, Sendable {
  var dialect: Dialect

  var defintions = [String: Schema]()
  var dynamicAnchors = [String: JSONPointer]()
}
