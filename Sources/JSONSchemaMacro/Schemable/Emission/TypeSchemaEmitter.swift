import SwiftSyntax
import SwiftSyntaxBuilder

enum TypeSchemaEmitter {
  static func expression(for type: SchemaType, inlineNamedTypes: Bool = false) -> ExprSyntax {
    switch type {
    case .scalar(let primitive):
      return "\(raw: primitive.schema)()"
    case .optional(let wrapped):
      return expression(for: wrapped, inlineNamedTypes: inlineNamedTypes)
    case .array(let element):
      return """
        JSONArray {
          \(expression(for: element, inlineNamedTypes: inlineNamedTypes))
        }
        """
    case .dictionary(let key, let value):
      let valueSchema = expression(for: value, inlineNamedTypes: inlineNamedTypes)
      if isStringKey(key) {
        return """
          JSONObject()
          .additionalProperties {
            \(valueSchema)
          }
          .map(\\.1)
          .map(\\.matches)
          """
      }
      return """
        JSONObject()
        .propertyNames { \(expression(for: key, inlineNamedTypes: inlineNamedTypes)) }
        .additionalProperties {
          \(valueSchema)
        }
        .map { value in
          let (_, capturedNames) = value.0
          let additionalProperties = value.1
          return Dictionary(
            uniqueKeysWithValues: zip(capturedNames.seen, capturedNames.raw)
              .compactMap { parsedKey, rawKey in
                additionalProperties.matches[rawKey].map { parsedValue in
                  (parsedKey, parsedValue)
                }
              }
          )
        }
        """
    case .named(let syntax):
      let argument = inlineNamedTypes ? ", inline: true" : ""
      return """
        JSONReusable(\(syntax.trimmed).self\(raw: argument)) {
          \(syntax.trimmed).schema
        }
        """
    case .selfReference:
      return "JSONDynamicReference<Self>()"
    }
  }

  private static func isStringKey(_ type: SchemaType) -> Bool {
    switch type {
    case .scalar(.string): true
    case .optional(let wrapped): isStringKey(wrapped)
    default: false
    }
  }
}
