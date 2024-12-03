import Foundation
import JSONSchema

/// A component for use in ``JSONSchemaBuilder`` to build, annotate, and validate schemas.
public protocol JSONSchemaComponent<Output>: Sendable {
  associatedtype Output

  var schemaValue: [KeywordIdentifier: JSONValue] { get set }

  /// Parse a JSON instance into a Swift type using the schema.
  /// - Parameter value: The value (aka instance or document) to validate.
  /// - Returns: A validated output or error messages.
  @Sendable func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue>
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
  ) throws -> Parsed<Output, ParseIssue> {
    let value = try decoder.decode(JSONValue.self, from: Data(instance.utf8))
    return parse(value)
  }

  public func parseAndValidate(
    instance: String,
    decoder: JSONDecoder = JSONDecoder()
  ) throws(ParseAndValidateIssue) -> Output {
    let value: JSONValue
    do {
      value = try decoder.decode(JSONValue.self, from: Data(instance.utf8))
    } catch {
      throw .decodingFailed(error)
    }
    let parsingResult = parse(value)
    let validationResult = definition().validate(value)
    switch (parsingResult, validationResult.isValid) {
    case (.valid(let output), true):
      return output
    case (.valid, false):
      throw .validationFailed(validationResult)
    case (.invalid(let errors), false):
      throw .parsingAndValidationFailed(errors, validationResult)
    case (.invalid(let errors), true):
      // This case should really not be possible
      throw .parsingFailed(errors)
    }
  }
}

public enum ParseAndValidateIssue: Error {
  case decodingFailed(Error)
  case parsingFailed([ParseIssue])
  case validationFailed(ValidationResult)
  case parsingAndValidationFailed([ParseIssue], ValidationResult)
}
