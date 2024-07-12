import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

func assertMacroExpansion(
  _ originalSource: String,
  expandedSource expectedExpandedSource: String,
  macros: [String: Macro.Type],
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  line: UInt = #line,
  column: UInt = #column
) {
  assertMacroExpansion(
    originalSource,
    expandedSource: expectedExpandedSource,
    macroSpecs: macros.mapValues { MacroSpec(type: $0) },
    indentationWidth: .spaces(2),
    failureHandler: { spec in
      Issue.record(
        "\(spec.message)",
        sourceLocation: .init(
          fileID: spec.location.fileID,
          filePath: spec.location.filePath,
          line: spec.location.line,
          column: spec.location.column
        )
      )
    },
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column
  )
}
