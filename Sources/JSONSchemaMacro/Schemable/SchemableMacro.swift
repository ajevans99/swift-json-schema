import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SchemableError: Error { case unsupportedDeclaration }

extension SchemableError: CustomStringConvertible {
  var description: String {
    switch self {
    case .unsupportedDeclaration: "Macro can only be applied to struct or class"
    }
  }
}

public struct SchemableMacro: MemberMacro, ExtensionMacro {
  /// Extract access level from declaration modifiers
  private static func extractAccessLevel(from declaration: some DeclGroupSyntax) -> String? {
    return declaration.modifiers.first { modifier in
      ["public", "internal", "package", "fileprivate", "private"].contains(modifier.name.text)
    }?.name.text
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Get the access level from the declaration - only add it for private/fileprivate
    let accessLevel = declaration.modifiers.first { modifier in
      ["private", "fileprivate"].contains(modifier.name.text)
    }?
    .name.text

    // Create extension with access level if present
    let extensionDecl = try ExtensionDeclSyntax(
      """
      \(raw: accessLevel.map { "\($0) " } ?? "")extension \(type.trimmed): Schemable {}
      """
    )

    return [extensionDecl]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Get the access level from the declaration
    let accessLevel = extractAccessLevel(from: declaration)
    let accessModifier = accessLevel.map { "\($0) " } ?? ""

    if let structDecl = declaration.as(StructDeclSyntax.self) {
      let strategyArg = node.arguments?
        .as(LabeledExprListSyntax.self)?
        .first(where: { $0.label?.text == "keyStrategy" })?
        .expression
      let generator = SchemaGenerator(fromStruct: structDecl, keyStrategy: strategyArg)
      let schemaDecl = generator.makeSchema()
      var decls: [DeclSyntax] = [schemaDecl]
      if let strategyArg {
        let property: DeclSyntax = """
          \(raw: accessModifier)static var keyEncodingStrategy: KeyEncodingStrategies { \(strategyArg) }
          """
        decls.append(property)
      }
      return decls
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
      let strategyArg = node.arguments?
        .as(LabeledExprListSyntax.self)?
        .first(where: { $0.label?.text == "keyStrategy" })?
        .expression
      let generator = SchemaGenerator(fromClass: classDecl, keyStrategy: strategyArg)
      let schemaDecl = generator.makeSchema()
      var decls: [DeclSyntax] = [schemaDecl]
      if let strategyArg {
        let property: DeclSyntax = """
          \(raw: accessModifier)static var keyEncodingStrategy: KeyEncodingStrategies { \(strategyArg) }
          """
        decls.append(property)
      }
      return decls
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      let strategyArg = node.arguments?
        .as(LabeledExprListSyntax.self)?
        .first(where: { $0.label?.text == "keyStrategy" })?
        .expression
      let generator = EnumSchemaGenerator(fromEnum: enumDecl)
      let schemaDecl = generator.makeSchema()
      var decls: [DeclSyntax] = [schemaDecl]
      if let strategyArg {
        let property: DeclSyntax = """
          \(raw: accessModifier)static var keyEncodingStrategy: KeyEncodingStrategies { \(strategyArg) }
          """
        decls.append(property)
      }
      return decls
    }

    throw SchemableError.unsupportedDeclaration
  }
}
