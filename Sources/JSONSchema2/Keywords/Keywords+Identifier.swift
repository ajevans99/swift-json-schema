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
//      guard case .object(let object) = schema else { return }
//      for (key, value) in object {
//        let subschemaLocation = location.appending(.key(key))
//        if let schema = try? Schema(rawSchema: value, location: subschemaLocation, context: context) {
//        }
//      }
    }
  }

  struct Anchor: IdentifierKeyword {
    static let name = "$anchor"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func processIdentifier(into context: Context) {
      guard let anchorName = schema.string else { return }
      context.anchors[anchorName] = location
    }
  }

  struct DynamicAnchor: IdentifierKeyword {
    static let name = "$dynamicAnchor"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    func processIdentifier(into context: Context) {
      guard let anchorName = schema.string else { return }
      context.dynamicAnchors[anchorName] = location
    }
  }
}

import Foundation

protocol ReferenceKeyword: Keyword {
  func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
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

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
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

      if let cachedSchema = context.schemaCache[referenceURI] {
        let result = cachedSchema.validate(input, at: location)
        if !result.valid {
          throw .referenceValidationFailure(ref: referenceURI, errors: result.errors ?? [])
        }
        return
      }

      guard let resolvedSchema = try resolveSchema(from: referenceURI, at: location, context: context) else {
        throw .invalidReference("Unable to resolve $ref '\(referenceURI)' at \(instanceLocation)")
      }

      // Update cache
      context.schemaCache[referenceURI] = resolvedSchema

      let result = resolvedSchema.validate(input, at: instanceLocation)
      if !result.valid {
        throw .referenceValidationFailure(ref: referenceURI, errors: result.errors ?? [])
      }
    }

    private func resolveSchema(from referenceURI: String, at instanceLocation: JSONPointer, context: Context) throws(ValidationIssue) -> Schema? {
      // Resolve the URI against the base URI
//      guard let baseURI = context.baseURI else {
//        throw ValidationIssue.invalidReference("No base URI to resolve $ref '\(referenceURI)' at \(location)")
//      }

      guard let resolvedURI = URL(string: referenceURI, relativeTo: nil)?.absoluteURL else {
        throw ValidationIssue.invalidReference("Invalid $ref URI '\(referenceURI)' at \(instanceLocation)")
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

      let pointer = context.anchors[fragment] ?? JSONPointer(from: fragment)
      guard let value = context.rootRawSchema?.value(at: pointer) else {
        return nil
      }
      return try? Schema(rawSchema: value, location: location, context: context)

//      if let anchorLocation = context.anchors[fragment] {
//
//
//      } else {
//        let pointer = JSONPointer(from: uri.relativePath)
//        guard let value = context.rootRawSchema?.value(at: pointer) else {
//          return nil
//        }
//        let schema = try? Schema(rawSchema: value, location: location, context: context)
//        return schema
//      }
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
