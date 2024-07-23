import SwiftSyntax
import SwiftSyntaxMacros

public struct ExcludeFromSchemaMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] { [] }
}
