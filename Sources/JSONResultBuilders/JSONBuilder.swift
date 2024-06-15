@resultBuilder
public struct JSONBuilder {
  public static func buildExpression(_ expression: JSONRepresentable?) -> JSONRepresentable {
    expression ?? JSONNullElement()
  }

  public static func buildBlock(_ expression: JSONRepresentable...) -> JSONRepresentable {
    if expression.count == 1 {
      expression[0]
    } else {
      JSONArrayElement(elements: expression)
    }
  }

  // MARK: Type hints

  public static func buildExpression(_ expression: String) -> JSONStringElement {
    JSONStringElement(string: expression)
  }

  public static func buildExpression(_ expression: Int) -> JSONIntegerElement {
    JSONIntegerElement(integer: expression)
  }

  public static func buildExpression(_ expression: Double) -> JSONNumberElement {
    JSONNumberElement(number: expression)
  }

  public static func buildExpression(_ expression: Bool) -> JSONBooleanElement {
    JSONBooleanElement(boolean: expression)
  }

  public static func buildExpression(_ expression: [JSONRepresentable]) -> JSONArrayElement {
    JSONArrayElement(elements: expression)
  }

  public static func buildExpression(_ expression: [String: JSONRepresentable]) -> JSONObjectElement {
    JSONObjectElement(properties: expression)
  }

  // MARK: Advanced builers

  public static func buildArray(_ components: [JSONRepresentable]) -> JSONRepresentable {
    JSONArrayElement(elements: components)
  }

  public static func buildOptional(_ component: JSONRepresentable?) -> JSONRepresentable {
    component ?? JSONNullElement()
  }

  public static func buildEither(first: JSONRepresentable) -> JSONRepresentable {
    first
  }

  public static func buildEither(second: JSONRepresentable) -> JSONRepresentable {
    second
  }
}
