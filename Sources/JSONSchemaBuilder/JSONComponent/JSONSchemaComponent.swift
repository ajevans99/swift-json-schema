import Foundation
import JSONSchema

/// A component for use in ``JSONSchemaBuilder`` to build, annotate, and validate schemas.
public protocol JSONSchemaComponent<Output>: Sendable {
  associatedtype Output

  var schemaValue: SchemaValue { get set }

  /// Parse a JSON instance into a Swift type using the schema.
  /// - Parameter value: The value (aka instance or document) to validate.
  /// - Returns: A validated output or error messages.
  @Sendable func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue>
}

extension JSONSchemaComponent {
  public func definition(context: Context = .init(dialect: .draft2020_12)) -> Schema {
    switch schemaValue {
    case .boolean(let bool):
      BooleanSchema(
        schemaValue: bool,
        location: .init(),
        context: context
      )
      .asSchema()
    case .object(let dict):
      ObjectSchema(
        schemaValue: dict,
        location: .init(),
        context: context
      )
      .asSchema()
    }
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
    decoder: JSONDecoder = JSONDecoder(),
    validationContext: Context = .init(dialect: .draft2020_12)
  ) throws(ParseAndValidateIssue) -> Output {
    let value: JSONValue
    do {
      value = try decoder.decode(JSONValue.self, from: Data(instance.utf8))
    } catch {
      throw .decodingFailed(error)
    }
    return try parseAndValidate(value, validationContext: validationContext)
  }

  public func parseAndValidate(
    _ value: JSONValue,
    validationContext: Context = .init(dialect: .draft2020_12)
  ) throws(ParseAndValidateIssue) -> Output {
    let parsingResult = parse(value)
    let validationResult = definition(context: validationContext).validate(value)
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
