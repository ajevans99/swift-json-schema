protocol IdentifierKeyword: Keyword {
  func processIdentifier(into context: Context)
}

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-id-keyword
  struct Identifier: IdentifierKeyword {
    static let name = "$id"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func processIdentifier(into context: Context) {

    }
  }

  struct Defs: IdentifierKeyword {
    static let name = "$defs"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func processIdentifier(into context: Context) {
      guard case .object(let object) = schema else { return }
      for (key, value) in object {
        let subschemaLocation = location.appending(.key(key))
        if let schema = try? Schema(rawSchema: value, location: subschemaLocation, context: context) {
          context.definitions[key] = schema
        }
      }
    }
  }

  struct Anchor: IdentifierKeyword {
    static let name = "$ref"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func processIdentifier(into context: Context) {}
  }

  struct DynamicAnchor: IdentifierKeyword {
    static let name = "$dynamicAnchor"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func processIdentifier(into context: Context) {
      guard case let .string(string) = schema else { return }
      context.dynamicAnchors[string] = location
    }
  }
}

import Foundation

protocol ReferenceKeyword: Keyword {
  func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
}

extension Keywords {
  struct Reference: ReferenceKeyword {
    static let name = "$ref"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
    private let referenceURI: String

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.referenceURI = schema.string ?? ""
    }

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard !context.validationStack.contains(referenceURI) else {
        // Detected a cycle, prevent infinite recursion
        print("Cycle detected. Stack: \(context.validationStack.map(\.description).joined(separator: ","))")
        return
      }
      context.validationStack.insert(referenceURI)
      defer { context.validationStack.remove(referenceURI) }

      guard !referenceURI.isEmpty else {
        return
      }

      guard let resolvedSchema = try resolveSchema(from: referenceURI, at: self.location, context: context) else {
        throw .invalidReference("Unable to resolve $ref '\(referenceURI)' at \(location)")
      }

      let result = resolvedSchema.validate(input, at: location)
      if !result.valid {
        throw .referenceValidationFailed
      }
    }

    private func resolveSchema(from referenceURI: String, at location: JSONPointer, context: Context) throws(ValidationIssue) -> Schema? {
      // Resolve the URI against the base URI
//      guard let baseURI = context.baseURI else {
//        throw ValidationIssue.invalidReference("No base URI to resolve $ref '\(referenceURI)' at \(location)")
//      }

      guard let resolvedURI = URL(string: referenceURI, relativeTo: nil)?.absoluteURL else {
        throw ValidationIssue.invalidReference("Invalid $ref URI '\(referenceURI)' at \(location)")
      }

      if resolvedURI.fragment != nil {
        return try resolveInternalReference(resolvedURI, context: context)
      } else {
        // Handle external references (not fully implemented)
        return nil
      }
    }

    private func resolveInternalReference(_ uri: URL, context: Context) throws(ValidationIssue) -> Schema? {
      guard let fragment = uri.fragment else {
        return nil
      }

      let pointer = JSONPointer(from: fragment)
      guard let value = context.rootRawSchema?.value(at: pointer) else {
        return nil
      }
      let schema = try? Schema(rawSchema: value, location: location, context: context)
      return schema
    }
  }

  struct DynamicReference: ReferenceKeyword {
    static let name = "$dynamicRef"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue){

    }
  }
}
