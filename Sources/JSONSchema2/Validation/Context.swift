/// Container for information used when validating a schema.
struct Context {
  var dialect: Dialect

  var defintions: [String: Schema]
  var dynamicAnchors: [String: JSONPointer]
}
