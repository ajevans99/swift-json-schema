import JSONSchema

/// A property that can project its Swift output back into an optional JSON member.
public protocol JSONPropertyPrinter: JSONPropertyComponent {
  /// A nil result omits the member; `.null` emits an explicit JSON null.
  func printProperty(_ output: Output) throws -> JSONValue?
}

extension JSONProperty: JSONPropertyPrinter where Value: JSONSchemaPrinter {
  public func printProperty(_ output: Value.Output?) throws -> JSONValue? {
    try output.map { try value.print($0) }
  }
}

extension JSONPropertyComponent where Value: JSONSchemaPrinter {
  /// Supplies the inverse of a property's mapping, including required properties.
  /// Return nil to omit the property and `.some` to print through its value schema.
  public func printing(
    _ unapply: @escaping (Output) throws -> Value.Output?
  ) -> JSONPrintingProperty<Self> {
    .init(upstream: self, unapply: unapply)
  }
}

public struct JSONPrintingProperty<Upstream: JSONPropertyComponent>: JSONPropertyPrinter
where Upstream.Value: JSONSchemaPrinter {
  let upstream: Upstream
  let unapply: (Upstream.Output) throws -> Upstream.Value.Output?

  public var key: String { upstream.key }
  public var isRequired: Bool { upstream.isRequired }
  public var value: Upstream.Value { upstream.value }

  public func parse(_ input: [String: JSONValue]) -> Parsed<Upstream.Output, ParseIssue> {
    upstream.parse(input)
  }

  public func printProperty(_ output: Upstream.Output) throws -> JSONValue? {
    try unapply(output).map { try value.print($0) }
  }
}

public protocol JSONPropertyCollectionPrinter: PropertyCollection {
  func printProperties(_ output: Output) throws -> JSONValue
}

extension EmptyPropertyCollection: JSONPropertyCollectionPrinter {
  public func printProperties(_ output: Void) -> JSONValue { .object([:]) }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension PropertyTuple: JSONPropertyCollectionPrinter
where repeat each Property: JSONPropertyPrinter {
  public func printProperties(_ output: (repeat (each Property).Output)) throws -> JSONValue {
    var result = SchemaValue.object([:])
    var keys = Set<String>()
    func append<P: JSONPropertyPrinter>(_ property: P, _ output: P.Output) throws {
      guard keys.insert(property.key).inserted else {
        throw JSONPrintingError.duplicateProperty(property.key)
      }
      if let value = try property.printProperty(output) {
        result[property.key] = value
      }
    }
    repeat try append(each property, each output)
    return result.value
  }
}

extension JSONObject: JSONSchemaPrinter where Props: JSONPropertyCollectionPrinter {
  public func print(_ output: Props.Output) throws -> JSONValue {
    try properties.printProperties(output)
  }
}
