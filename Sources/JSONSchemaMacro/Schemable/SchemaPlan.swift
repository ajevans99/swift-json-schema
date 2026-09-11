import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder

struct PlannedMember {
  let source: SchemableMember
  let field: FieldPlan
}

enum MemberPlan {
  case included(PlannedMember)
  case excluded(SchemableMember)
  case unsupported(SchemableMember)

  var included: PlannedMember? {
    if case .included(let member) = self { return member }
    return nil
  }
}

struct PayloadField {
  let label: TokenSyntax?
  let field: FieldPlan
}

enum EnumCasePlan {
  case simple(SchemableEnumCase)
  case payload(SchemableEnumCase, [PayloadField])
  case unsupported(SchemableEnumCase)
}

struct SchemaPlan {
  enum Body {
    case object([MemberPlan])
    case enumeration([EnumCasePlan])
  }

  let declaration: SchemableDeclaration
  let configuration: MacroConfiguration
  let body: Body
  let diagnostics: [Diagnostic]
}

enum SchemaPlanner {
  static func plan(
    _ declaration: SchemableDeclaration,
    configuration: MacroConfiguration
  ) -> SchemaPlan {
    let diagnostics = DiagnosticCollector()
    for diagnostic in declaration.diagnostics + declaration.options.diagnostics {
      diagnostics.diagnose(diagnostic)
    }
    let declarationValidator = SchemaOptionsDiagnostics(
      propertyName: declaration.name,
      propertyType: TypeSyntax(IdentifierTypeSyntax(name: declaration.name)),
      schemaType: .named(TypeSyntax(IdentifierTypeSyntax(name: declaration.name))),
      context: diagnostics
    )
    declarationValidator.validateSchemaOptions(declaration.options.options(for: .schema))
    if declaration.kind != .enumeration {
      declarationValidator.validateTypeSpecificOptions(
        declaration.options.options(for: .object),
        macroName: OptionAttribute.object.rawValue
      )
    }
    let body: SchemaPlan.Body
    switch declaration.kind {
    case .structure, .classType:
      let members = declaration.properties.map {
        planMember(
          $0,
          declaration: declaration,
          configuration: configuration,
          diagnostics: diagnostics
        )
      }
      InitializerDiagnostics(
        typeName: declaration.name,
        allMembers: declaration.properties,
        initializers: declaration.initializers,
        isClass: declaration.kind == .classType,
        context: diagnostics
      )
      .emitDiagnostics(for: members.compactMap(\.included).map(\.source))
      body = .object(members)
    case .enumeration:
      body = .enumeration(declaration.cases.map { planCase($0, diagnostics: diagnostics) })
    }
    return SchemaPlan(
      declaration: declaration,
      configuration: configuration,
      body: body,
      diagnostics: diagnostics.diagnostics
    )
  }

  private static func planMember(
    _ member: SchemableMember,
    declaration: SchemableDeclaration,
    configuration: MacroConfiguration,
    diagnostics: DiagnosticCollector
  ) -> MemberPlan {
    if member.isExcluded { return .excluded(member) }
    for diagnostic in member.options.diagnostics { diagnostics.diagnose(diagnostic) }
    let type: SchemaType
    switch SchemaType.parse(member.type) {
    case .success(let parsed):
      type = parsed.resolvingSelfReferences(named: declaration.name.text.trimmingBackticks())
    case .failure:
      diagnostics.diagnose(
        Diagnostic(
          node: member.identifier,
          message: UnsupportedTypeDiagnostic.propertyTypeNotSupported(
            propertyName: member.identifier.text,
            typeName: member.type.trimmedDescription
          )
        )
      )
      return .unsupported(member)
    }

    let validator = SchemaOptionsDiagnostics(
      propertyName: member.identifier,
      propertyType: member.type,
      schemaType: type,
      context: diagnostics
    )
    let generalOptions = member.options.options(for: .schema)
    validator.validateSchemaOptions(generalOptions)
    for group in member.options.typeSpecific {
      validator.validateTypeSpecificOptions(group.options, macroName: group.attribute.rawValue)
    }

    var customKey: ExprSyntax?
    var nullStyle: ExprSyntax?
    for option in generalOptions {
      switch option.kind {
      case .key(let value): customKey = value
      case .orNull(let style): nullStyle = style
      default: break
      }
    }
    if nullStyle == nil, configuration.optionalNulls {
      nullStyle =
        type.isScalar ? ".type" : "\(raw: configuration.optionalNullUnion.orNullStyleAccessor)"
    }

    let key: ExprSyntax
    if let customKey {
      key = customKey
    } else if let codingKey = declaration.codingKeys?[member.identifier.text.trimmingBackticks()] {
      key = "\(literal: codingKey)"
    } else if configuration.keyStrategy != nil {
      key =
        "\(declaration.name).keyEncodingStrategy.encode(\(literal: member.identifier.text.trimmingBackticks()))"
    } else {
      key = "\(literal: member.identifier.text.trimmingBackticks())"
    }

    let field = FieldPlanner.plan(
      type: type,
      key: key,
      defaultValue: member.defaultValue,
      docString: member.docString,
      options: generalOptions + member.options.typeSpecific.flatMap(\.options),
      nullStyle: nullStyle
    )
    return .included(PlannedMember(source: member, field: field))
  }

  private static func planCase(
    _ enumCase: SchemableEnumCase,
    diagnostics: DiagnosticCollector
  ) -> EnumCasePlan {
    guard let parameters = enumCase.associatedValues else { return .simple(enumCase) }
    var fields: [PayloadField] = []
    var isUnsupported = false
    for (index, parameter) in parameters.enumerated() {
      switch SchemaType.parse(parameter.type) {
      case .success(let type):
        let label = parameter.firstName.flatMap { $0.text == "_" ? nil : $0.trimmed }
        let key = parameter.firstName?.text.trimmingBackticks() ?? "_\(index)"
        fields.append(
          PayloadField(
            label: label,
            field: FieldPlanner.plan(
              type: type,
              key: "\(literal: key)",
              defaultValue: parameter.defaultValue?.value,
              docString: parameter.docString
            )
          )
        )
      case .failure:
        isUnsupported = true
        diagnostics.diagnose(
          Diagnostic(
            node: parameter.type,
            message: UnsupportedTypeDiagnostic.enumPayloadNotSupported(
              caseName: enumCase.identifier.text,
              typeName: parameter.type.trimmedDescription
            )
          )
        )
      }
    }
    // Never build a case constructor from a partially emitted payload.
    return isUnsupported ? .unsupported(enumCase) : .payload(enumCase, fields)
  }
}
