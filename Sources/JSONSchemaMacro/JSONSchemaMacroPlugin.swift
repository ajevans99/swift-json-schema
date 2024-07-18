import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main struct JSONSchemaMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    SchemableMacro.self, SchemaOptionsMacro.self, NumberOptionsMacro.self, ArrayOptionsMacro.self,
    ObjectOptionsMacro.self, StringOptionsMacro.self,
  ]
}
