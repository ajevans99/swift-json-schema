@resultBuilder
public struct JSONValueBuilder {
  public static func buildExpression(_ expression: JSONValueRepresentable?) -> JSONValueRepresentable {
    expression ?? JSONNullValue()
  }

  public static func buildBlock(_ expression: JSONValueRepresentable...) -> JSONValueRepresentable {
    if expression.count == 1 {
      expression[0]
    } else {
      JSONArrayValue(elements: expression)
    }
  }

  // MARK: Type hints

  public static func buildExpression(_ expression: String) -> JSONStringValue {
    JSONStringValue(string: expression)
  }

  public static func buildExpression(_ expression: Int) -> JSONIntegerValue {
    JSONIntegerValue(integer: expression)
  }

  public static func buildExpression(_ expression: Double) -> JSONNumberValue {
    JSONNumberValue(number: expression)
  }

  public static func buildExpression(_ expression: Bool) -> JSONBooleanValue {
    JSONBooleanValue(boolean: expression)
  }

  public static func buildExpression(_ expression: [JSONValueRepresentable]) -> JSONArrayValue {
    JSONArrayValue(elements: expression)
  }

  public static func buildExpression(_ expression: [String: JSONValueRepresentable]) -> JSONObjectValue {
    JSONObjectValue(properties: expression)
  }

  // MARK: Additional array type hints

  public static func buildExpression(_ expression: [String]) -> JSONArrayValue {
    JSONArrayValue(elements: expression.map { JSONStringValue(string: $0) })
  }

  public static func buildExpression(_ expression: [Int]) -> JSONArrayValue {
    JSONArrayValue(elements: expression.map { JSONIntegerValue(integer: $0) })
  }

  public static func buildExpression(_ expression: [Double]) -> JSONArrayValue {
    JSONArrayValue(elements: expression.map { JSONNumberValue(number: $0) })
  }

  public static func buildExpression(_ expression: [Bool]) -> JSONArrayValue {
    JSONArrayValue(elements: expression.map { JSONBooleanValue(boolean: $0) })
  }

  public static func buildExpression(_ expression: [JSONValueRepresentable?]) -> JSONArrayValue {
    JSONArrayValue(elements: expression.map { $0 ?? JSONNullValue() })
  }

  // MARK: Addition dictionary type hints

  public static func buildExpression(_ expression: [String: Int]) -> JSONObjectValue {
    JSONObjectValue(properties: expression.mapValues { JSONIntegerValue(integer: $0) })
  }

  public static func buildExpression(_ expression: [String: Double]) -> JSONObjectValue {
    JSONObjectValue(properties: expression.mapValues { JSONNumberValue(number: $0) })
  }

  public static func buildExpression(_ expression: [String: Bool]) -> JSONObjectValue {
    JSONObjectValue(properties: expression.mapValues { JSONBooleanValue(boolean: $0) })
  }

  public static func buildExpression(_ expression: [String: String]) -> JSONObjectValue {
    JSONObjectValue(properties: expression.mapValues { JSONStringValue(string: $0) })
  }

  public static func buildExpression(_ expression: [String: JSONValueRepresentable?]) -> JSONObjectValue {
    JSONObjectValue(properties: expression.mapValues { $0 ?? JSONNullValue() })
  }

  // MARK: Advanced builers

  public static func buildArray(_ components: [JSONValueRepresentable]) -> JSONValueRepresentable {
    JSONArrayValue(elements: components)
  }

  public static func buildOptional(_ component: JSONValueRepresentable?) -> JSONValueRepresentable {
    component ?? JSONNullValue()
  }

  public static func buildEither(first: JSONValueRepresentable) -> JSONValueRepresentable {
    first
  }

  public static func buildEither(second: JSONValueRepresentable) -> JSONValueRepresentable {
    second
  }
}
