import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Handles validation and diagnostics for initializer matching in @Schemable types
struct InitializerDiagnostics {
  let typeName: TokenSyntax
  let members: MemberBlockItemListSyntax
  let context: any MacroExpansionContext

  /// Emits diagnostics when the generated schema may not match the memberwise initializer
  func emitDiagnostics(for schemableMembers: [SchemableMember]) {
    // Get ALL stored properties (including excluded ones) to check init mismatch
    let allStoredProperties = getAllStoredProperties()
    let excludedProperties = allStoredProperties.filter { prop in
      !schemableMembers.contains(where: { $0.identifier.text == prop.name })
    }

    // Build expected parameter list from schema members
    let expectedParameters: [(name: String, type: String)] = schemableMembers.map { member in
      (
        name: member.identifier.text,
        type: member.type.description.trimmingCharacters(in: .whitespaces)
      )
    }

    // Try to find an explicit initializer
    let explicitInits = members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }

    if let memberWiseInit = findMatchingInit(explicitInits, expectedParameters: expectedParameters)
    {
      // Found a matching explicit init - validate it matches exactly
      validateInitParameters(memberWiseInit, expectedParameters: expectedParameters)
    } else if !explicitInits.isEmpty {
      // Has explicit inits but none match - warn about this
      emitNoMatchingInitWarning(
        expectedParameters: expectedParameters,
        availableInits: explicitInits,
        excludedProperties: excludedProperties
      )
    } else {
      // No explicit init - will use synthesized memberwise init
      // Check for conditions that would break the synthesized init
      validateSynthesizedInitRequirements(schemableMembers: schemableMembers)
    }
  }

  /// Gets all stored properties including those marked with @ExcludeFromSchema
  private func getAllStoredProperties() -> [(name: String, type: String, isExcluded: Bool)] {
    members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
      .filter { !$0.isStatic }
      .flatMap { variableDecl in
        variableDecl.bindings.compactMap { binding -> (String, String, Bool)? in
          guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let type = binding.typeAnnotation?.type,
            binding.isStoredProperty
          else { return nil }

          let isExcluded = !variableDecl.shouldExcludeFromSchema
          return (
            name: identifier.text,
            type: type.description.trimmingCharacters(in: .whitespaces),
            isExcluded: isExcluded
          )
        }
      }
  }

  /// Finds an initializer that matches the expected parameters
  private func findMatchingInit(
    _ inits: [InitializerDeclSyntax],
    expectedParameters: [(name: String, type: String)]
  ) -> InitializerDeclSyntax? {
    for initDecl in inits {
      let params = initDecl.signature.parameterClause.parameters
      if params.count == expectedParameters.count {
        let matches = zip(params, expectedParameters)
          .allSatisfy { param, expected in
            let paramName = param.secondName?.text ?? param.firstName.text
            return paramName == expected.name
          }
        if matches {
          return initDecl
        }
      }
    }
    return nil
  }

  /// Validates that an explicit init's parameters match the schema exactly
  private func validateInitParameters(
    _ initDecl: InitializerDeclSyntax,
    expectedParameters: [(name: String, type: String)]
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
      }

      // Check if types are obviously different (note: this is string comparison, not semantic)
      if paramType != expected.type {
        let diagnostic = Diagnostic(
          node: param.type,
          message: InitializerMismatchDiagnostic.parameterTypeMismatch(
            parameterName: paramName,
            expectedType: expected.type,
            actualType: paramType
          )
        )
        context.diagnose(diagnostic)
      }
    }
  }

  /// Emits a warning when no matching initializer is found
  private func emitNoMatchingInitWarning(
    expectedParameters: [(name: String, type: String)],
    availableInits: [InitializerDeclSyntax],
    excludedProperties: [(name: String, type: String, isExcluded: Bool)]
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
    for member in schemableMembers where member.defaultValue != nil {
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


          Note: The following properties are excluded from the schema using @ExcludeFromSchema: \(excludedList)
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
