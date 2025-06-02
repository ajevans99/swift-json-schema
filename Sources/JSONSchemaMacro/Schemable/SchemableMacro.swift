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
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Get the access level from the declaration
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
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      let generator = SchemaGenerator(fromStruct: structDecl)
      let schemaDecl = generator.makeSchema()
      return [schemaDecl]
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
      let generator = SchemaGenerator(fromClass: classDecl)
      let schemaDecl = generator.makeSchema()
      return [schemaDecl]
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      let generator = EnumSchemaGenerator(fromEnum: enumDecl)
      let schemaDecl = generator.makeSchema()
      return [schemaDecl]
    }

    throw SchemableError.unsupportedDeclaration
  }
}
