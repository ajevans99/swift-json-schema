import JSONSchema
import OrderedCollections

extension JSONSchemaComponent {
  /// Explicitly exports scalar-keyed output, rejecting names that collide as Swift Strings.
  public func stringKeyedDictionary<Value>() -> JSONComponents.StringKeyedDictionary<Self, Value>
  where Output == [JSONKey: Value] {
    .init(upstream: self)
  }
}

extension JSONComponents {
  public struct StringKeyedDictionary<Upstream: JSONSchemaComponent, Value>: JSONSchemaComponent
  where Upstream.Output == [JSONKey: Value] {
    var upstream: Upstream

    public var schemaValue: SchemaValue {
      get { upstream.schemaValue }
      set { upstream.schemaValue = newValue }
    }

    public func parse(_ value: JSONValue) -> Parsed<[String: Value], ParseIssue> {
      upstream.parse(value)
        .flatMap { output in
          do throws(JSONKeyConversionError) {
            return .valid(
              try OrderedDictionary<JSONKey, Value>(uniqueKeysWithValues: output)
                .stringKeyedDictionary()
            )
          } catch {
            return .error(.keyConversionFailed(error))
          }
        }
    }
  }
}
