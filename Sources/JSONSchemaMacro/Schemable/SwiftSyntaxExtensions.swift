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
    case primative(SupportedPrimative, schema: CodeBlockItemSyntax)
    case schemable(String, schema: CodeBlockItemSyntax)
    case notSupported

    var codeBlock: CodeBlockItemSyntax? {
      switch self {
      case .primative(_, let schema): schema
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
      return .primative(
        .array,
        schema: """
          JSONArray {
            \(codeBlock)
          }
          """
      )
    case .dictionaryType(let dictionaryType):
      guard let keyType = dictionaryType.key.as(IdentifierTypeSyntax.self),
        keyType.name.text == "String"
      else { return .notSupported }
      guard let codeBlock = dictionaryType.value.typeInformation().codeBlock else {
        return .notSupported
      }
      return .primative(
        .dictionary,
        schema: """
          JSONObject()
          .additionalProperties {
            \(codeBlock)
          }
          .map(\\.1)
          """
      )
    case .identifierType(let identifierType):
      if let generic = identifierType.genericArgumentClause {
        guard identifierType.name.text != "Array" else {
          let arrayType = ArrayTypeSyntax(element: generic.arguments.first!.argument)
          return TypeSyntax(arrayType).typeInformation()
        }

        guard identifierType.name.text != "Dictionary" else {
          let test = Array(generic.arguments.prefix(2))
          let dictionaryType = DictionaryTypeSyntax(key: test[0].argument, value: test[1].argument)
          return TypeSyntax(dictionaryType).typeInformation()
        }
      }

      guard let primative = SupportedPrimative(rawValue: identifierType.name.text) else {
        return .schemable(
          identifierType.name.text,
          schema: "\(raw: identifierType.name.text).schema"
        )
      }

      return .primative(primative, schema: "\(raw: primative.schema)()")
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

extension VariableDeclSyntax {
  var shouldExcludedFromSchema: Bool {
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
      .filter { $0.0.shouldExcludedFromSchema }.filter { $0.1.isStoredProperty }
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
      .map { CodeBlockItemSyntax(leadingTrivia: $0.offset == 0 ? nil : separator, item: $0.element.item) }
    self.init(newChildren)
  }
}
