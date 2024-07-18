import SwiftSyntax

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

extension MemberBlockItemListSyntax {
  func schemableMembers() -> [SchemableMember] {
    self.compactMap { $0.decl.as(VariableDeclSyntax.self) }
      .flatMap { variableDecl in variableDecl.bindings.map { (variableDecl, $0) } }
      .filter { $0.1.isStoredProperty }
      .compactMap { (variableDecl, patternBinding) -> SchemableMember? in
        guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier
        else { return nil }
        guard let type = patternBinding.typeAnnotation?.type else { return nil }

        return SchemableMember(
          identifier: identifier,
          type: type,
          attributes: variableDecl.attributes
        )
      }
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

extension TypeSyntax {
  func jsonSchemaCodeBlock() -> CodeBlockItemSyntax? {
    switch self.as(TypeSyntaxEnum.self) {
    case .arrayType(let arrayType):
      guard let type = arrayType.element.jsonSchemaCodeBlock() else { return nil }
      return """
        JSONArray()
        .items {
          \(type)
        }
        """
    case .dictionaryType(let dictionaryType):
      guard let keyType = dictionaryType.key.as(IdentifierTypeSyntax.self),
        keyType.name.text == "String"
      else {
        // TODO: Add warning
        return nil
      }
      guard let type = dictionaryType.value.jsonSchemaCodeBlock() else { return nil }
      return """
        JSONObject()
        .additionalProperties {
          \(type)
        }
        """
    case .identifierType(let identifierType):
      guard let type = jsonType(from: identifierType.name.text) else {
        return "\(raw: identifierType.name.text).schema"
      }
      return "\(type)()"
    case .implicitlyUnwrappedOptionalType(let implicitlyUnwrappedOptionalType):
      return implicitlyUnwrappedOptionalType.wrappedType.jsonSchemaCodeBlock()
    case .optionalType(let optionalType): return optionalType.wrappedType.jsonSchemaCodeBlock()
    case .someOrAnyType(let someOrAnyType): return someOrAnyType.constraint.jsonSchemaCodeBlock()
    case .attributedType, .classRestrictionType, .compositionType, .functionType, .memberType,
      .metatypeType, .missingType, .namedOpaqueReturnType, .packElementType, .packExpansionType,
      .suppressedType, .tupleType:
      return nil
    }
  }

  func jsonType(from text: String) -> DeclReferenceExprSyntax? {
    let identifier: String? =
      switch text {
      case "Double": "JSONNumber"
      case "Bool": "JSONBoolean"
      case "Int": "JSONInteger"
      case "String": "JSONString"
      default: nil
      }
    guard let identifier else { return nil }
    return .init(baseName: .identifier(identifier))
  }
}
