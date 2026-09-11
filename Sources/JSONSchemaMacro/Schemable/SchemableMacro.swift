import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SchemableError: Error, CustomStringConvertible {
  case unsupportedDeclaration

  var description: String { "Macro can only be applied to struct, class, or enum" }
}

public struct SchemableMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // The member role owns diagnostics for unsupported declarations.
    guard
      declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self)
        || declaration.is(EnumDeclSyntax.self)
    else { return [] }
    return [try ExtensionDeclSyntax("extension \(type.trimmed): Schemable {}")]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let configuration = try MacroConfiguration(attribute: node)
    let declaration = try SchemableDeclaration(declaration, lexicalContext: context.lexicalContext)
    let plan = SchemaPlanner.plan(declaration, configuration: configuration)
    for diagnostic in plan.diagnostics {
      context.diagnose(diagnostic)
    }
    return SchemaEmitter.declarations(for: plan)
  }
}
