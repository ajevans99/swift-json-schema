import JSONSchema

@attached(peer)
public macro SchemaOptions(
  _ traits: SchemaTrait...
) = #externalMacro(module: "JSONSchemaMacro", type: "SchemaOptionsMacro")

public protocol SchemaTrait {}

public struct SchemaOptionsTrait: SchemaTrait {
  fileprivate init() {}

  fileprivate static let errorMessage =
    "This method should only be used within @SchemaOptions macro"
}

extension SchemaTrait where Self == SchemaOptionsTrait {
  public static func title(_ value: String) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func description(_ value: String) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func key(_ value: String) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func `default`(_ value: JSONValue) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func examples(_ value: JSONValue) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func format(_ value: String) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func readOnly(_ value: Bool) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func writeOnly(_ value: Bool) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func deprecated(_ value: Bool) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }

  public static func comment(_ value: String) -> SchemaOptionsTrait {
    fatalError(SchemaOptionsTrait.errorMessage)
  }
}
