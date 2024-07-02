import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main struct JSONSchemaMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [SchemableMacro.self]
}
