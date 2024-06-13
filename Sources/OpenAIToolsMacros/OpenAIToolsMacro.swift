import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) -> ExprSyntax {
    guard let argument = node.arguments.first?.expression else {
      fatalError("compiler bug: the macro does not have any arguments")
    }

    return "(\(argument), \(literal: argument.description))"
  }
}

public enum ToolParameterError: Error {
  case mustApplyToVariable
  case unknownType
  case couldNotParseType
}

public struct ToolParameterMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
      throw ToolParameterError.mustApplyToVariable
    }

    guard let binding = varDecl.bindings.first,
          let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
          let type = binding.typeAnnotation?.type.description else {
      throw ToolParameterError.couldNotParseType
    }

    let typeDescription: String
    if type.contains("String") {
      typeDescription = "\"type\": \"string\""
    } else {
      throw ToolParameterError.unknownType
    }

    var propertySchema = """
        "\(identifier)": {\(typeDescription)
        """

    // Parse the @ToolParameter attribute.
    let attributeInfo = AttributeInfo(byParsing: node)

    if let description = attributeInfo.description {
      propertySchema += ", \"description\": \(description)"
    }

    propertySchema += "}"

    // Wrap the propertySchema in triple quotes
    let schemaString = """
        \"\"\"
        {
          \(propertySchema)
        }
        \"\"\"
        """

    let newDecl = try VariableDeclSyntax("static let schema: String = \(raw: schemaString)")

    return [DeclSyntax(newDecl)]
  }
}

@main
struct OpenAIToolsPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    StringifyMacro.self,
    ToolParameterMacro.self,
  ]
}
