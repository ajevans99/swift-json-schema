/// A protocol that enables type-safe, schema-driven conversion from JSON to custom Foundation types.
///
/// `CustomSchemaConvertible` allows you to create custom conversion types that can be used
/// with the ``@SchemaOptions(.customSchema(_:))`` macro modifier to provide type-safe JSON parsing
/// and validation for custom types like `UUID`, `Date`, `URL`, and other Foundation types.
///
/// ## Usage
///
/// To use custom schema conversions in your macros, extend the `Conversions` enum with your
/// custom conversion types:
///
/// ```swift
/// import JSONSchemaBuilder
/// import JSONSchemaConversion
///
/// extension Conversions {
///   public static let uuid = UUIDConversion()
///   public static let dateTime = DateTimeConversion()
///   public static let url = URLConversion()
/// }
/// ```
///
/// Then use them in your `@Schemable` types:
///
/// ```swift
/// @Schemable
/// struct MyModel {
///   @SchemaOptions(.customSchema(.uuid))
///   let id: UUID
///
///   @SchemaOptions(.customSchema(.dateTime))
///   let createdAt: Date
///
///   @SchemaOptions(.customSchema(.url))
///   let website: URL
/// }
/// ```
///
/// This ensures that only valid UUID strings, ISO 8601 date strings, and valid URLs are accepted
/// during JSON parsing and validation, providing compile-time type safety and runtime validation.
///
/// ## Implementation
///
/// When implementing `CustomSchemaConvertible`, you must:
/// 1. Specify the `Output` associated type (the Foundation type you're converting to)
/// 2. Provide a `schema` property that returns a `JSONSchemaComponent<Output>`
/// 3. Extend the ``Conversions`` enum with your custom conversion types
///
/// The schema should include appropriate validation rules for your custom type, such as
/// format validation for UUIDs, date-time formats, or URL patterns.
public protocol CustomSchemaConvertible {
  associatedtype Output

  @JSONSchemaBuilder
  var schema: any JSONSchemaComponent<Output> { get }
}
