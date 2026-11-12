import JSONSchema

/// A schema with an explicit inverse from its Swift output to a JSON value.
///
/// Printing does not enforce schema constraints. Use `printAndValidate` when the
/// produced value must satisfy the schema. Arbitrary parse-only mappings do not
/// conform: an inverse must be provided explicitly.
public protocol JSONSchemaPrinter<Output>: JSONSchemaComponent {
  func print(_ output: Output) throws -> JSONValue
}

public enum JSONPrintingError: Error {
  case nonFiniteNumber
  case validationFailed(ValidationResult)
  case duplicateProperty(String)
}

extension JSONSchemaPrinter {
  /// Prints and validates using the receiver's current schema metadata.
  public func printAndValidate(
    _ output: Output,
    validationContext: Context = .init(dialect: .draft2020_12)
  ) throws -> JSONValue {
    let value = try print(output)
    let result = definition(context: validationContext).validate(value)
    guard result.isValid else { throw JSONPrintingError.validationFailed(result) }
    return value
  }

  /// Maps in both directions. The caller is responsible for inverse laws.
  public func map<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput,
    unapply: @escaping (NewOutput) throws -> Output
  ) -> JSONPrintedMap<Self, NewOutput> {
    .init(upstream: self, transform: transform, unapply: unapply)
  }
}

extension JSONSchemaComponent {
  /// Supplies an explicit projection for a parse-only schema, without Codable.
  /// The projection must agree with the parsing semantics of this schema.
  public func printing(
    _ projection: @escaping (Output) throws -> JSONValue
  ) -> JSONPrintingSchema<Self> {
    .init(upstream: self, projection: projection)
  }
}

public struct JSONPrintingSchema<Upstream: JSONSchemaComponent>: JSONSchemaPrinter {
  var upstream: Upstream
  let projection: (Upstream.Output) throws -> JSONValue

  public var schemaValue: SchemaValue {
    get { upstream.schemaValue }
    set { upstream.schemaValue = newValue }
  }

  public func parse(_ value: JSONValue) -> Parsed<Upstream.Output, ParseIssue> {
    upstream.parse(value)
  }

  public func print(_ output: Upstream.Output) throws -> JSONValue {
    try projection(output)
  }
}

public struct JSONPrintedMap<Upstream: JSONSchemaPrinter, Output>: JSONSchemaPrinter {
  var upstream: Upstream
  let transform: (Upstream.Output) -> Output
  let unapply: (Output) throws -> Upstream.Output

  public var schemaValue: SchemaValue {
    get { upstream.schemaValue }
    set { upstream.schemaValue = newValue }
  }

  public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
    upstream.parse(value).map(transform)
  }

  public func print(_ output: Output) throws -> JSONValue {
    try upstream.print(unapply(output))
  }
}

extension JSONString: JSONSchemaPrinter {
  public func print(_ output: String) -> JSONValue { .string(output) }
}

extension JSONInteger: JSONSchemaPrinter {
  public func print(_ output: Int) -> JSONValue { .integer(output) }
}

extension JSONBoolean: JSONSchemaPrinter {
  public func print(_ output: Bool) -> JSONValue { .boolean(output) }
}

extension JSONNumber: JSONSchemaPrinter {
  public func print(_ output: Double) throws -> JSONValue {
    guard output.isFinite else { throw JSONPrintingError.nonFiniteNumber }
    return .number(output)
  }
}

extension JSONNull: JSONSchemaPrinter {
  public func print(_ output: Void) -> JSONValue { .null }
}

extension JSONArray: JSONSchemaPrinter where T: JSONSchemaPrinter {
  public func print(_ output: [T.Output]) throws -> JSONValue {
    .array(try output.map { try items.print($0) })
  }
}
