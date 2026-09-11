/// Defines the composition keyword that should be used when combining schemas.
public enum SchemaComposition {
  /// Uses the `oneOf` keyword when composing schemas.
  case oneOf
  /// Uses the `anyOf` keyword when composing schemas.
  case anyOf
}

/// Derives a schema and `Schemable` conformance for a struct, class, or enum.
///
/// Included stored properties must have explicit type annotations. Use boolean literals
/// for `optionalNulls` and explicit `.oneOf` or `.anyOf` cases for composition arguments;
/// the macro cannot evaluate arbitrary Swift expressions for these settings.
///
/// Unsupported property types produce a warning and are excluded. Unsupported enum
/// associated values produce an error rather than a partially generated case.
@attached(extension, conformances: Schemable)
@attached(member, names: named(schema), named(keyEncodingStrategy))
public macro Schemable(
  keyStrategy: KeyEncodingStrategies? = nil,
  optionalNulls: Bool = true,
  enumComposition: SchemaComposition = .oneOf,
  optionalNullUnion: SchemaComposition = .oneOf
) = #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable {
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  associatedtype Schema: JSONSchemaComponent

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  @JSONSchemaBuilder static var schema: Schema { get }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  static var keyEncodingStrategy: KeyEncodingStrategies { get }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  static var defaultAnchor: String { get }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension Schemable {
  public static var keyEncodingStrategy: KeyEncodingStrategies { .identity }

  public static var defaultAnchor: String {
    SchemaAnchorName.sanitized(String(reflecting: Self.self))
  }
}
