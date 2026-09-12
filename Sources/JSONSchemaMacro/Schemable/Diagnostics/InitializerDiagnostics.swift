import SwiftDiagnostics
import SwiftSyntax

/// Handles validation and diagnostics for initializer matching in @Schemable types
struct InitializerDiagnostics {
  let typeName: TokenSyntax
  let allMembers: [SchemableMember]
  let initializers: [InitializerDeclSyntax]
  let isClass: Bool
  let context: DiagnosticCollector

  /// Emits diagnostics when the generated schema may not match the memberwise initializer
  func emitDiagnostics(for schemableMembers: [SchemableMember]) {
    // Get ALL stored properties (including excluded ones) to check init mismatch
    let allStoredProperties = getAllStoredProperties()
    let excludedProperties = allStoredProperties.filter { prop in
      !schemableMembers.contains(where: { $0.identifier.text == prop.name })
    }

    // Build expected parameter list from schema members
    let expectedParameters: [(name: String, type: TypeSyntax)] = schemableMembers.map { member in
      (
        name: member.identifier.text,
        type: member.type.trimmed
      )
    }

    // Try to find an explicit initializer
    let explicitInits = initializers

    if let memberWiseInit = findMatchingInit(explicitInits, expectedParameters: expectedParameters)
    {
      // Validate the best candidate, preserving detailed diagnostics if no overload fits.
      validateInitParameters(memberWiseInit, expectedParameters: expectedParameters)
    } else if !explicitInits.isEmpty {
      // Has explicit inits but none match - warn about this
      emitNoMatchingInitWarning(
        expectedParameters: expectedParameters,
        availableInits: explicitInits,
        excludedProperties: excludedProperties
      )
    } else if !isClass {
      // Class initialization can depend on inheritance or extensions; leave it to Swift.
      validateSynthesizedInitRequirements(schemableMembers: schemableMembers)
    }
  }

  /// Gets all stored properties including those marked with @ExcludeFromSchema
  private func getAllStoredProperties() -> [(name: String, type: String)] {
    allMembers.map {
      (name: $0.identifier.text, type: $0.type.trimmedDescription)
    }
  }

  /// Prefers an exact match, retaining a name/count match for diagnostics if none fits.
  private func findMatchingInit(
    _ inits: [InitializerDeclSyntax],
    expectedParameters: [(name: String, type: TypeSyntax)]
  ) -> InitializerDeclSyntax? {
    let expectedNames = Set(expectedParameters.map { $0.name })
    var diagnosticCandidate: InitializerDeclSyntax?

    for initDecl in inits {
      let params = initDecl.signature.parameterClause.parameters
      guard params.count == expectedParameters.count else { continue }
      let paramNames = Set(params.map { $0.secondName?.text ?? $0.firstName.text })
      guard paramNames == expectedNames else { continue }

      if zip(params, expectedParameters)
        .allSatisfy({ param, expected in
          (param.secondName?.text ?? param.firstName.text) == expected.name
            && typesMatch(param.type, expected.type)
        })
      {
        return initDecl
      }

      diagnosticCandidate = diagnosticCandidate ?? initDecl
    }
    return diagnosticCandidate
  }

  /// Validates that an explicit init's parameters match the schema exactly
  private func validateInitParameters(
    _ initDecl: InitializerDeclSyntax,
    expectedParameters: [(name: String, type: TypeSyntax)]
  ) {
    let params = initDecl.signature.parameterClause.parameters
    for (index, (param, expected)) in zip(params, expectedParameters).enumerated() {
      let paramName = param.secondName?.text ?? param.firstName.text
      let paramType = param.type.description.trimmingCharacters(in: .whitespaces)

      // Check if parameter order is different
      if paramName != expected.name {
        let diagnostic = Diagnostic(
          node: param,
          message: InitializerMismatchDiagnostic.parameterOrderMismatch(
            position: index + 1,
            expectedName: expected.name,
            actualName: paramName
          )
        )
        context.diagnose(diagnostic)
      } else {
        // Only check types when names match (otherwise type comparison is meaningless)
        if !typesMatch(param.type, expected.type) {
          let diagnostic = Diagnostic(
            node: param.type,
            message: InitializerMismatchDiagnostic.parameterTypeMismatch(
              parameterName: paramName,
              expectedType: expected.type.trimmedDescription,
              actualType: paramType
            )
          )
          context.diagnose(diagnostic)
        }
      }
    }
  }

  private func typesMatch(_ lhs: TypeSyntax, _ rhs: TypeSyntax) -> Bool {
    guard case .success(let left) = SchemaType.parse(lhs),
      case .success(let right) = SchemaType.parse(rhs)
    else { return lhs.trimmedDescription == rhs.trimmedDescription }
    return typesMatch(left, right)
  }

  private func typesMatch(_ lhs: SchemaType, _ rhs: SchemaType) -> Bool {
    switch (lhs, rhs) {
    case (.scalar(let lhs), .scalar(let rhs)):
      return lhs == rhs
    case (.optional(let lhs), .optional(let rhs)), (.array(let lhs), .array(let rhs)):
      return typesMatch(lhs, rhs)
    case (.dictionary(let leftKey, let leftValue), .dictionary(let rightKey, let rightValue)):
      return typesMatch(leftKey, rightKey) && typesMatch(leftValue, rightValue)
    case (.named(let lhs), .named(let rhs)):
      return lhs.tokens(viewMode: .sourceAccurate).map(\.text)
        == rhs.tokens(viewMode: .sourceAccurate).map(\.text)
    case (.selfReference, .selfReference):
      return true
    default:
      return false
    }
  }

  /// Emits a warning when no matching initializer is found
  private func emitNoMatchingInitWarning(
    expectedParameters: [(name: String, type: TypeSyntax)],
    availableInits: [InitializerDeclSyntax],
    excludedProperties: [(name: String, type: String)]
  ) {
    let expectedSignature = expectedParameters.map { "\($0.name): \($0.type)" }
      .joined(separator: ", ")

    let availableSignatures = availableInits.map { initDecl -> String in
      let params = initDecl.signature.parameterClause.parameters
        .map { param in
          let name = param.secondName?.text ?? param.firstName.text
          let type = param.type.description.trimmingCharacters(in: .whitespaces)
          return "\(name): \(type)"
        }
        .joined(separator: ", ")
      return "init(\(params))"
    }

    let diagnostic = Diagnostic(
      node: typeName,
      message: InitializerMismatchDiagnostic.noMatchingInit(
        typeName: typeName.text,
        expectedSignature: expectedSignature,
        availableInits: availableSignatures,
        excludedProperties: excludedProperties.map { $0.name }
      )
    )
    context.diagnose(diagnostic)
  }

  /// Validates requirements for synthesized memberwise init
  private func validateSynthesizedInitRequirements(schemableMembers: [SchemableMember]) {
    // Check for properties with default values - these won't be in synthesized init
    // Only warn if there's a MIX of properties with and without defaults
    // (if ALL have defaults, the init() with no params is intentional and fine)
    let membersWithDefaults = schemableMembers.filter { !$0.isVariable && $0.defaultValue != nil }
    let membersWithoutDefaults = schemableMembers.filter { $0.defaultValue == nil }

    // Only emit diagnostic if there are BOTH properties with defaults AND without
    if !membersWithDefaults.isEmpty && !membersWithoutDefaults.isEmpty {
      for member in membersWithDefaults {
        let diagnostic = Diagnostic(
          node: member.identifier,
          message: InitializerMismatchDiagnostic.propertyHasDefault(
            propertyName: member.identifier.text
          )
        )
        context.diagnose(diagnostic)
      }
    }
  }
}

/// Diagnostic messages for initializer mismatches
enum InitializerMismatchDiagnostic: DiagnosticMessage {
  case propertyHasDefault(propertyName: String)
  case parameterOrderMismatch(position: Int, expectedName: String, actualName: String)
  case parameterTypeMismatch(parameterName: String, expectedType: String, actualType: String)
  case noMatchingInit(
    typeName: String,
    expectedSignature: String,
    availableInits: [String],
    excludedProperties: [String]
  )

  var message: String {
    switch self {
    case .propertyHasDefault(let propertyName):
      return
        "Property '\(propertyName)' has a default value which will be excluded from the memberwise initializer"

    case .parameterOrderMismatch(let position, let expectedName, let actualName):
      return """
        Initializer parameter at position \(position) is '\(actualName)' but schema expects '\(expectedName)'. \
        The schema will generate properties in a different order than the initializer parameters.
        """

    case .parameterTypeMismatch(let parameterName, let expectedType, let actualType):
      return """
        Parameter '\(parameterName)' has type '\(actualType)' but schema expects '\(expectedType)'. \
        This type mismatch will cause the generated schema to fail.
        """

    case .noMatchingInit(
      let typeName,
      let expectedSignature,
      let availableInits,
      let excludedProperties
    ):
      var msg = """
        Type '\(typeName)' has explicit initializers, but none match the expected schema signature.

        Expected: init(\(expectedSignature))
        """
      if !availableInits.isEmpty {
        msg += "\n\nAvailable initializers:"
        for initSig in availableInits {
          msg += "\n  - \(initSig)"
        }
      }
      if !excludedProperties.isEmpty {
        let excludedList = excludedProperties.map { "'\($0)'" }.joined(separator: ", ")
        msg += """


          Note: The following properties are excluded from the schema: \(excludedList)
          These will still be present in the memberwise initializer but not in the schema.
          """
      }
      msg += """


        The generated schema expects JSONSchema(\(typeName).init) to use an initializer that \
        matches all schema properties. Consider adding a matching initializer or adjusting the schema properties.
        """
      return msg
    }
  }

  var diagnosticID: MessageID {
    switch self {
    case .propertyHasDefault:
      return MessageID(domain: "JSONSchemaMacro", id: "propertyHasDefault")
    case .parameterOrderMismatch:
      return MessageID(domain: "JSONSchemaMacro", id: "parameterOrderMismatch")
    case .parameterTypeMismatch:
      return MessageID(domain: "JSONSchemaMacro", id: "parameterTypeMismatch")
    case .noMatchingInit:
      return MessageID(domain: "JSONSchemaMacro", id: "noMatchingInit")
    }
  }

  var severity: DiagnosticSeverity {
    switch self {
    case .propertyHasDefault:
      return .warning
    case .parameterOrderMismatch, .parameterTypeMismatch:
      return .error
    case .noMatchingInit:
      return .error
    }
  }
}
