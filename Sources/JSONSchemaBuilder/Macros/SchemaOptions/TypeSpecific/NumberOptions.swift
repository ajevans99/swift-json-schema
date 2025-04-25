import JSONSchema

@attached(peer)
public macro NumberOptions(
  _ traits: NumberTrait...
) = #externalMacro(module: "JSONSchemaMacro", type: "NumberOptionsMacro")

public protocol NumberTrait {}

public struct NumberSchemaTrait: NumberTrait {
  fileprivate init() {}

  fileprivate static let errorMessage =
    "This method should only be used within @NumberOptions macro"
}

extension NumberTrait where Self == NumberSchemaTrait {
  public static func multipleOf(_ value: Double) -> NumberSchemaTrait {
    fatalError(NumberSchemaTrait.errorMessage)
  }

  public static func minimum(_ value: Double) -> NumberSchemaTrait {
    fatalError(NumberSchemaTrait.errorMessage)
  }

  public static func exclusiveMinimum(_ value: Double) -> NumberSchemaTrait {
    fatalError(NumberSchemaTrait.errorMessage)
  }

  public static func maximum(_ value: Double) -> NumberSchemaTrait {
    fatalError(NumberSchemaTrait.errorMessage)
  }

  public static func exclusiveMaximum(_ value: Double) -> NumberSchemaTrait {
    fatalError(NumberSchemaTrait.errorMessage)
  }
}
