import JSONSchema

@attached(peer)
public macro StringOptions(
  _ traits: StringTrait...
) = #externalMacro(module: "JSONSchemaMacro", type: "StringOptionsMacro")

public protocol StringTrait {}

public struct StringSchemaTrait: StringTrait {
  fileprivate init() {}

  fileprivate static let errorMessage =
    "This method should only be used within @StringOptions macro"
}

extension StringTrait where Self == StringSchemaTrait {
  public static func minLength(_ value: Int) -> StringSchemaTrait {
    fatalError(StringSchemaTrait.errorMessage)
  }

  public static func maxLength(_ value: Int) -> StringSchemaTrait {
    fatalError(StringSchemaTrait.errorMessage)
  }

  public static func pattern(_ value: String) -> StringSchemaTrait {
    fatalError(StringSchemaTrait.errorMessage)
  }

  public static func format(_ value: String) -> StringSchemaTrait {
    fatalError(StringSchemaTrait.errorMessage)
  }
}
