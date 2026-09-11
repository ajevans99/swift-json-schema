import Foundation
import SwiftParser
import SwiftSyntax

extension String {
  /// Sanitizes a qualified type name by removing backticks from all components.
  /// For example, "Outer.`Inner`" becomes "Outer.Inner".
  func sanitizingQualifiedTypeName() -> String {
    self.split(separator: ".")
      .map {
        String($0).trimmingBackticks()
      }
      .joined(separator: ".")
  }
}

extension PatternBindingListSyntax.Element {
  // Modified implementation from https://github.com/swiftlang/swift-syntax/blob/248dcef04d9e03b7fc47905a81fc84c6f6c23837/Examples/Sources/MacroExamples/Implementation/MemberAttribute/WrapStoredPropertiesMacro.swift#L65
  var isStoredProperty: Bool {
    switch accessorBlock?.accessors {
    case .accessors(let accessors):
      for accessor in accessors {
        switch accessor.accessorSpecifier.tokenKind {
        case .keyword(.willSet), .keyword(.didSet):
          // Observers can occur on a stored property.
          break
        default:
          // Other accessors make it a computed property.
          return false
        }
      }
      return true
    case .getter: return false
    case nil: return true
    }
  }
}

extension SyntaxProtocol {
  var docString: String? {
    // Get the leading trivia which contains the docstring
    let trivia = leadingTrivia
    var docStringLines: [String] = []

    for piece in trivia {
      switch piece {
      case .docLineComment(let comment):
        // Remove the /// prefix and trim whitespace
        let line = String(comment.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        docStringLines.append(line)
      case .docBlockComment(let comment):
        // Remove the /** and */ and trim whitespace
        let content = comment.dropFirst(3).dropLast(2)
        let lines = content.split(separator: "\n")
        for line in lines {
          // Remove leading asterisks and trim whitespace
          let trimmed = line.trimmingCharacters(in: .whitespaces)
          if !trimmed.isEmpty {
            // Remove leading asterisk and any following whitespace
            let cleanLine =
              trimmed.hasPrefix("*")
              ? String(trimmed.dropFirst().trimmingCharacters(in: .whitespaces)) : trimmed
            docStringLines.append(cleanLine)
          }
        }
      default:
        break
      }
    }

    return docStringLines.isEmpty ? nil : docStringLines.joined(separator: "\n")
  }
}

extension VariableDeclSyntax {
  var isStatic: Bool {
    modifiers.contains { modifier in
      modifier.name.tokenKind == .keyword(.static)
    }
  }
}

extension MemberBlockItemListSyntax {
  func schemableEnumCases(isStringBacked: Bool) -> [SchemableEnumCase] {
    self.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
      .flatMap { caseDecl in caseDecl.elements.map { (caseDecl, $0) } }
      .map {
        SchemableEnumCase(enumCaseDecl: $0.0, caseElement: $0.1, isStringBacked: isStringBacked)
      }
  }

  /// Extracts CodingKeys mapping from a CodingKeys enum if present
  func extractCodingKeys() -> [String: String]? {
    // Look for an enum named "CodingKeys"
    guard
      let codingKeysEnum = self.compactMap({ $0.decl.as(EnumDeclSyntax.self) })
        .first(where: { $0.name.text == "CodingKeys" })
    else {
      return nil
    }

    var mapping: [String: String] = [:]

    // Iterate through enum cases to extract the mapping
    for member in codingKeysEnum.memberBlock.members {
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }

      for element in caseDecl.elements {
        let caseName = element.name.text.trimmingBackticks()

        // Check if there's a raw value (string literal)
        if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self),
          let stringValue = rawValue.representedLiteralValue
        {
          mapping[caseName] = stringValue
        } else {
          // If no raw value is specified, the case name is the coding key
          mapping[caseName] = caseName
        }
      }
    }

    return mapping.isEmpty ? nil : mapping
  }
}

extension CodeBlockItemListSyntax {
  init(_ children: [CodeBlockItemSyntax], separator: Trivia) {
    let newChildren = children.enumerated()
      .map {
        CodeBlockItemSyntax(leadingTrivia: $0.offset == 0 ? nil : separator, item: $0.element.item)
      }
    self.init(newChildren)
  }
}
