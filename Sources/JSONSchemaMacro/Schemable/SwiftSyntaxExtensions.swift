import Foundation
import SwiftSyntax

extension TypeSyntax {
  var isOptional: Bool {
    // Check for explicit optional like `let snow: Optional<Double>`
    if let identifierType = self.as(IdentifierTypeSyntax.self) {
      return identifierType.name.text == "Optional"
    }

    // Check for postfix optional like `let rain: Double?`
    return self.is(OptionalTypeSyntax.self)
  }

  enum TypeInformation {
    case primitive(SupportedPrimitive, schema: CodeBlockItemSyntax)
    case schemable(String, schema: CodeBlockItemSyntax)
    case notSupported

    var codeBlock: CodeBlockItemSyntax? {
      switch self {
      case .primitive(_, let schema): schema
      case .schemable(_, let schema): schema
      case .notSupported: nil
      }
    }
  }

  func typeInformation() -> TypeInformation {
    switch self.as(TypeSyntaxEnum.self) {
    case .arrayType(let arrayType):
      guard let codeBlock = arrayType.element.typeInformation().codeBlock else {
        return .notSupported
      }
      return .primitive(
        .array,
        schema: """
          JSONArray {
            \(codeBlock)
          }
          """
      )
    #if canImport(SwiftSyntax602)
      case .inlineArrayType(let inlineArrayType):
        guard
          case GenericArgumentSyntax.Argument.type(let elementType) = inlineArrayType.element
            .argument
        else {
          // The other enum value `.expr` requires an @spi(ExperimentalLanguageFeature) import of SwiftSyntax
          return .notSupported
        }
        guard let codeBlock = elementType.typeInformation().codeBlock else {
          return .notSupported
        }
        return .primitive(
          .array,
          schema: """
            JSONArray {
              \(codeBlock)
            }
            """
        )
    #endif
    case .dictionaryType(let dictionaryType):
      let keyTypeInfo = dictionaryType.key.typeInformation()
      let valueTypeInfo = dictionaryType.value.typeInformation()
      guard let valueCodeBlock = valueTypeInfo.codeBlock else { return .notSupported }

      switch keyTypeInfo {
      case .primitive(let primitive, _):
        guard primitive == .string else { return .notSupported }

        let mapMatches =
          switch valueTypeInfo {
          case .schemable, .primitive: "\n.map(\\.matches)"
          case .notSupported: ""
          }

        return .primitive(
          .dictionary,
          schema: """
            JSONObject()
            .additionalProperties {
              \(valueCodeBlock)
            }
            .map(\\.1)\(raw: mapMatches)
            """
        )

      case .schemable(_, let keySchema):
        return .primitive(
          .dictionary,
          schema: """
            JSONObject()
            .propertyNames { \(raw: keySchema) }
            .additionalProperties {
              \(valueCodeBlock)
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
        )

      case .notSupported:
        return .notSupported
      }
    case .identifierType(let identifierType):
      if let generic = identifierType.genericArgumentClause {
        guard identifierType.name.text != "Array" else {
          #if canImport(SwiftSyntax601)
            let argument = generic.arguments.first!.argument
            guard case GenericArgumentSyntax.Argument.type(let element) = argument else {
              // The other enum value `.expr` requires an @spi(ExperimentalLangaugeFeature) import of SwiftSyntax
              fatalError("swift-json-schema error: Failed to get Array type, please open an issue")
            }
            let arrayType = ArrayTypeSyntax(element: element)
          #else
            let arrayType = ArrayTypeSyntax(element: generic.arguments.first!.argument)
          #endif
          return TypeSyntax(arrayType).typeInformation()
        }

        guard identifierType.name.text != "Dictionary" else {
          let test = Array(generic.arguments.prefix(2))
          #if canImport(SwiftSyntax601)
            guard case GenericArgumentSyntax.Argument.type(let key) = test[0].argument,
              case GenericArgumentSyntax.Argument.type(let value) = test[1].argument
            else {
              // The other enum value `.expr` requires an @spi(ExperimentalLangaugeFeature) import of SwiftSyntax
              fatalError(
                "swift-json-schema error: Failed to get Dictionary type, please open an issue"
              )
            }
            let dictionaryType = DictionaryTypeSyntax(key: key, value: value)
          #else
            let dictionaryType = DictionaryTypeSyntax(
              key: test[0].argument,
              value: test[1].argument
            )
          #endif
          return TypeSyntax(dictionaryType).typeInformation()
        }
      }

      guard let primitive = SupportedPrimitive(rawValue: identifierType.name.text) else {
        return .schemable(
          identifierType.name.text,
          schema: "\(raw: identifierType.name.text).schema"
        )
      }

      return .primitive(primitive, schema: "\(raw: primitive.schema)()")
    case .implicitlyUnwrappedOptionalType(let implicitlyUnwrappedOptionalType):
      return implicitlyUnwrappedOptionalType.wrappedType.typeInformation()
    case .optionalType(let optionalType): return optionalType.wrappedType.typeInformation()
    case .someOrAnyType(let someOrAnyType): return someOrAnyType.constraint.typeInformation()
    case .attributedType, .classRestrictionType, .compositionType, .functionType, .memberType,
      .metatypeType, .missingType, .namedOpaqueReturnType, .packElementType, .packExpansionType,
      .suppressedType, .tupleType:
      return .notSupported
    }
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
  var shouldExcludeFromSchema: Bool {
    !attributes.compactMap {
      $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text
    }
    .contains(where: { $0 == "ExcludeFromSchema" })
  }
}

extension MemberBlockItemListSyntax {
  func schemableMembers() -> [SchemableMember] {
    self.compactMap { $0.decl.as(VariableDeclSyntax.self) }
      .flatMap { variableDecl in variableDecl.bindings.map { (variableDecl, $0) } }
      .filter { $0.0.shouldExcludeFromSchema }.filter { $0.1.isStoredProperty }
      .compactMap(SchemableMember.init)
  }

  func schemableEnumCases() -> [SchemableEnumCase] {
    self.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
      .flatMap { caseDecl in caseDecl.elements.map { (caseDecl, $0) } }.map(SchemableEnumCase.init)
  }
}

extension CodeBlockItemSyntax {
  mutating func applyArguments(_ arguments: LabeledExprListSyntax) {
    for argument in arguments {
      if let label = argument.label {
        self = """
          \(self)
          .\(label.trimmed)(\(argument.expression))
          """
      }
    }
  }
}

extension AttributeListSyntax {
  func arguments(for attributeName: String) -> LabeledExprListSyntax? {
    self.compactMap { $0.as(AttributeSyntax.self) }
      .first {
        guard let attributeIdentifier = $0.attributeName.as(IdentifierTypeSyntax.self) else {
          return false
        }
        return attributeIdentifier.name.text == attributeName
      }?
      .arguments?
      .as(LabeledExprListSyntax.self)
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
