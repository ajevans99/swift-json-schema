import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

func identifierExpr(_ name: String) -> ExprSyntax {
  ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
}

func identifierExpr(_ token: TokenSyntax) -> ExprSyntax {
  ExprSyntax(DeclReferenceExprSyntax(baseName: token))
}

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

  func unwrappedOptionalType() -> TypeSyntax? {
    switch self.as(TypeSyntaxEnum.self) {
    case .optionalType(let optionalType):
      return optionalType.wrappedType
    case .implicitlyUnwrappedOptionalType(let implicitlyUnwrappedOptionalType):
      return implicitlyUnwrappedOptionalType.wrappedType
    case .identifierType(let identifierType):
      guard identifierType.name.text == "Optional",
        let arguments = identifierType.genericArgumentClause?.arguments.first
      else { return nil }
      #if canImport(SwiftSyntax601)
        guard case GenericArgumentSyntax.Argument.type(let wrappedType) = arguments.argument else {
          return nil
        }
        return wrappedType
      #else
        return arguments.argument
      #endif
    default:
      return nil
    }
  }

  func encodeExpression(
    valueExpr: ExprSyntax,
    customSchema: ExprSyntax?,
    context: String
  ) -> ExprSyntax? {
    if let customSchema {
      return "\(customSchema).encode(\(valueExpr))"
    }

    switch self.as(TypeSyntaxEnum.self) {
    case .identifierType(let identifierType):
      if let generic = identifierType.genericArgumentClause {
        if identifierType.name.text == "Array" {
          #if canImport(SwiftSyntax601)
            guard
              let firstArgument = generic.arguments.first,
              case GenericArgumentSyntax.Argument.type(let element) = firstArgument.argument
            else { return nil }
            return TypeSyntax(ArrayTypeSyntax(element: element))
              .encodeExpression(valueExpr: valueExpr, customSchema: nil, context: context)
          #else
            guard let element = generic.arguments.first?.argument else { return nil }
            return TypeSyntax(ArrayTypeSyntax(element: element))
              .encodeExpression(valueExpr: valueExpr, customSchema: nil, context: context)
          #endif
        }

        if identifierType.name.text == "Dictionary" {
          let arguments = Array(generic.arguments.prefix(2))
          guard arguments.count == 2 else { return nil }
          #if canImport(SwiftSyntax601)
            guard case GenericArgumentSyntax.Argument.type(let key) = arguments[0].argument,
              case GenericArgumentSyntax.Argument.type(let value) = arguments[1].argument
            else { return nil }
            return TypeSyntax(DictionaryTypeSyntax(key: key, value: value))
              .encodeExpression(valueExpr: valueExpr, customSchema: nil, context: context)
          #else
            return TypeSyntax(
              DictionaryTypeSyntax(
                key: arguments[0].argument,
                value: arguments[1].argument
              )
            )
            .encodeExpression(valueExpr: valueExpr, customSchema: nil, context: context)
          #endif
        }
      }

      let name = identifierType.name.text
      switch name {
      case "String":
        return "JSONValue.string(\(valueExpr))"
      case "Double":
        return "JSONValue.number(\(valueExpr))"
      case "Float":
        return "JSONValue.number(Double(\(valueExpr)))"
      case "Int":
        return "JSONValue.integer(\(valueExpr))"
      case "Bool":
        return "JSONValue.boolean(\(valueExpr))"
      case "JSONValue":
        return valueExpr
      default:
        return "\(valueExpr).toJSONValue()"
      }
    case .arrayType(let arrayType):
      return encodeArray(arrayType, valueExpr: valueExpr, context: context)
    case .dictionaryType(let dictionaryType):
      return encodeDictionary(dictionaryType, valueExpr: valueExpr, context: context)
    case .implicitlyUnwrappedOptionalType(let implicitlyUnwrappedOptionalType):
      return implicitlyUnwrappedOptionalType.wrappedType.encodeExpression(
        valueExpr: valueExpr,
        customSchema: customSchema,
        context: context
      )
    case .optionalType(let optionalType):
      return optionalType.wrappedType.encodeExpression(
        valueExpr: valueExpr,
        customSchema: customSchema,
        context: context
      )
    case .someOrAnyType(let someOrAnyType):
      return someOrAnyType.constraint.encodeExpression(
        valueExpr: valueExpr,
        customSchema: customSchema,
        context: context
      )
    case .memberType:
      return "\(valueExpr).toJSONValue()"
    case .metatypeType(let metatypeType):
      return metatypeType.baseType.encodeExpression(
        valueExpr: valueExpr,
        customSchema: customSchema,
        context: context
      )
    default:
      return nil
    }
  }

  private func encodeArray(
    _ arrayType: ArrayTypeSyntax,
    valueExpr: ExprSyntax,
    context: String
  ) -> ExprSyntax? {
    let elementType = arrayType.element
    if elementType.isJSONValueType {
      return "JSONValue.array(\(valueExpr))"
    }

    if let wrapped = elementType.unwrappedOptionalType() {
      guard
        let wrappedExpr = wrapped.encodeExpression(
          valueExpr: identifierExpr("nonNilElement"),
          customSchema: nil,
          context: "\(context)[]"
        )
      else { return nil }
      return """
        JSONValue.array(
          \(valueExpr).map { element in
            if let nonNilElement = element {
              \(wrappedExpr)
            } else {
              JSONValue.null
            }
          }
        )
        """
    }

    guard
      let elementExpr = elementType.encodeExpression(
        valueExpr: identifierExpr("element"),
        customSchema: nil,
        context: "\(context)[]"
      )
    else { return nil }

    return """
      JSONValue.array(
        \(valueExpr).map { element in
          \(elementExpr)
        }
      )
      """
  }

  private func encodeDictionary(
    _ dictionaryType: DictionaryTypeSyntax,
    valueExpr: ExprSyntax,
    context: String
  ) -> ExprSyntax? {
    let valueContext = "\(context)[value]"

    if dictionaryType.key.isStringType {
      guard
        let valueExprSyntax = dictionaryType.value.encodeExpression(
          valueExpr: identifierExpr("value"),
          customSchema: nil,
          context: valueContext
        )
      else { return nil }
        return """
        {
          var dictionary: [String: JSONValue] = [:]
          for (key, value) in \(valueExpr) {
            dictionary[key] = \(valueExprSyntax)
          }
          return JSONValue.object(dictionary)
        }()
        """
    }

    return nil
  }

  private var isJSONValueType: Bool {
    switch self.as(TypeSyntaxEnum.self) {
    case .identifierType(let identifierType):
      return identifierType.name.text == "JSONValue"
    default:
      return false
    }
  }

  private var isStringType: Bool {
    switch self.as(TypeSyntaxEnum.self) {
    case .identifierType(let identifierType):
      return identifierType.name.text == "String"
    default:
      return false
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
