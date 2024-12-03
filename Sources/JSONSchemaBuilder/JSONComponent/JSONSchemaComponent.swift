import Foundation
import JSONSchema

/// A component for use in ``JSONSchemaBuilder`` to build, annotate, and validate schemas.
public protocol JSONSchemaComponent<Output>: Sendable {
  associatedtype Output

  var schemaValue: [KeywordIdentifier: JSONValue] { get set }

  /// Parse a JSON instance into a Swift type using the schema.
  /// - Parameter value: The value (aka instance or document) to validate.
  /// - Returns: A validated output or error messages.
  @Sendable func parse(_ value: JSONValue) -> Parsed<Output, String>
}

extension JSONSchemaComponent {
  public func definition() -> Schema {
    ObjectSchema(
      schemaValue: schemaValue,
      location: .init(),
      context: .init(dialect: .draft2020_12)
    )
    .asSchema()
  }

  public func parse(
    instance: String,
    decoder: JSONDecoder = JSONDecoder()
  ) throws -> Parsed<Output, String> {
    let value = try decoder.decode(JSONValue.self, from: Data(instance.utf8))
    return parse(value)
  }
}
