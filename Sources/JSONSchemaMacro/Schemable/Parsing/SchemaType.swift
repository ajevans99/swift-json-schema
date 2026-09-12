import SwiftSyntax

struct UnsupportedSchemaType: Error {
  let syntax: TypeSyntax
}

/// The supported structure of a field's type, independent of schema source generation.
indirect enum SchemaType {
  case scalar(SupportedPrimitive)
  case optional(SchemaType)
  case array(SchemaType)
  case dictionary(key: SchemaType, value: SchemaType)
  case named(TypeSyntax)
  case selfReference

  static func parse(_ syntax: TypeSyntax) -> Result<SchemaType, UnsupportedSchemaType> {
    guard let type = analyze(syntax) else {
      return .failure(UnsupportedSchemaType(syntax: syntax))
    }
    return .success(type)
  }

  var isOptional: Bool {
    if case .optional = self { return true }
    return false
  }

  var isScalar: Bool {
    switch self {
    case .scalar(let primitive): primitive.isScalar
    case .optional(let wrapped): wrapped.isScalar
    case .array, .dictionary, .named, .selfReference: false
    }
  }

  var isPrimitive: Bool {
    switch self {
    case .scalar, .array, .dictionary: true
    case .optional(let wrapped): wrapped.isPrimitive
    case .named, .selfReference: false
    }
  }

  var usesSelfReference: Bool {
    switch self {
    case .selfReference: true
    case .optional(let wrapped), .array(let wrapped): wrapped.usesSelfReference
    case .dictionary(let key, let value): key.usesSelfReference || value.usesSelfReference
    case .scalar, .named: false
    }
  }

  func resolvingSelfReferences(named name: String) -> SchemaType {
    switch self {
    case .optional(let wrapped):
      return .optional(wrapped.resolvingSelfReferences(named: name))
    case .array(let element):
      return .array(element.resolvingSelfReferences(named: name))
    case .dictionary(let key, let value):
      return .dictionary(
        key: key.resolvingSelfReferences(named: name),
        value: value.resolvingSelfReferences(named: name)
      )
    case .named(let syntax):
      let typeName = syntax.trimmedDescription.sanitizingQualifiedTypeName()
      if typeName == "Self" || typeName == name.sanitizingQualifiedTypeName() {
        return .selfReference
      }
      return self
    case .scalar, .selfReference:
      return self
    }
  }

  private static func analyze(_ syntax: TypeSyntax) -> SchemaType? {
    guard !syntax.hasError else { return nil }

    switch syntax.as(TypeSyntaxEnum.self) {
    case .arrayType(let array):
      return analyze(array.element).map(SchemaType.array)
    #if canImport(SwiftSyntax602)
      case .inlineArrayType(let array):
        guard let element = argumentType(array.element) else { return nil }
        return analyze(element).map(SchemaType.array)
    #endif
    case .dictionaryType(let dictionary):
      return analyzeDictionary(key: dictionary.key, value: dictionary.value)
    case .optionalType(let optional):
      return analyze(optional.wrappedType).map(SchemaType.optional)
    case .implicitlyUnwrappedOptionalType(let optional):
      return analyze(optional.wrappedType).map(SchemaType.optional)
    case .identifierType(let identifier):
      return analyzeNamed(
        syntax,
        name: identifier.name.text.trimmingBackticks(),
        arguments: identifier.genericArgumentClause
      )
    case .memberType(let member):
      if let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text.trimmingBackticks() == "Swift",
        base.genericArgumentClause == nil
      {
        return analyzeNamed(
          syntax,
          name: member.name.text.trimmingBackticks(),
          arguments: member.genericArgumentClause
        )
      }
      return .named(syntax)
    case .someOrAnyType(let constrained):
      return analyze(constrained.constraint)
    case .attributedType, .classRestrictionType, .compositionType, .functionType,
      .metatypeType, .missingType, .namedOpaqueReturnType, .packElementType, .packExpansionType,
      .suppressedType, .tupleType:
      return nil
    }
  }

  private static func analyzeNamed(
    _ syntax: TypeSyntax,
    name: String,
    arguments: GenericArgumentClauseSyntax?
  ) -> SchemaType? {
    switch name {
    case "Optional", "Array":
      guard let arguments, arguments.arguments.count == 1,
        let argument = arguments.arguments.first.flatMap(argumentType),
        let wrapped = analyze(argument)
      else { return nil }
      return name == "Optional" ? .optional(wrapped) : .array(wrapped)
    case "Dictionary":
      guard let arguments, arguments.arguments.count == 2,
        let key = arguments.arguments.first.flatMap(argumentType),
        let value = arguments.arguments.last.flatMap(argumentType)
      else { return nil }
      return analyzeDictionary(key: key, value: value)
    default:
      if let primitive = SupportedPrimitive(rawValue: name), primitive.isScalar {
        guard arguments == nil else { return nil }
        return .scalar(primitive)
      }
      return .named(syntax)
    }
  }

  private static func analyzeDictionary(key: TypeSyntax, value: TypeSyntax) -> SchemaType? {
    guard let key = analyze(key), key.isSupportedDictionaryKey,
      let value = analyze(value)
    else { return nil }
    return .dictionary(key: key, value: value)
  }

  private var isSupportedDictionaryKey: Bool {
    switch self {
    case .scalar(.string), .named: true
    case .optional(let wrapped): wrapped.isSupportedDictionaryKey
    case .scalar, .array, .dictionary, .selfReference: false
    }
  }

  private static func argumentType(_ argument: GenericArgumentSyntax) -> TypeSyntax? {
    #if canImport(SwiftSyntax601)
      guard case .type(let type) = argument.argument else { return nil }
      return type
    #else
      return argument.argument
    #endif
  }
}
