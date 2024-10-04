protocol IdentifierKeyword: Keyword {
  func processIdentifier()
}

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-id-keyword
  struct Identifier: IdentifierKeyword {
    static let name = "$id"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier() {}

    func processSubschema(baseURI: URL?) -> URL? {
      if let string = value.string, let newURL = URL(string: string, relativeTo: baseURI) {
        context.context.identifierRegistry[newURL.absoluteURL] = context.location
        return newURL.absoluteURL
      }
      return baseURI
    }
  }

  struct Defs: IdentifierKeyword {
    static let name = "$defs"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier() {
      guard case .object(let object) = value else { return }
      for (key, value) in object {
        // It is important to process defs to update context
        let subschemaLocation = context.location.appending(.key(key))
        _ = try? Schema(rawSchema: value, location: subschemaLocation, context: context.context, baseURI: context.uri)
      }
    }
  }

  struct Anchor: IdentifierKeyword {
    static let name = "$anchor"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier() {
      guard let anchorName = value.string else { return }
      context.context.anchors[anchorName] = context.location
    }
  }

  struct DynamicAnchor: IdentifierKeyword {
    static let name = "$dynamicAnchor"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier() {
      guard let anchorName = value.string else { return }
      context.context.dynamicAnchors[anchorName] = context.location
    }
  }
}

import Foundation

protocol ReferenceKeyword: Keyword {
  func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context, baseURI: URL?) throws(ValidationIssue)
}

extension Keywords {
  struct Reference: ReferenceKeyword {
    static let name = "$ref"

    let value: JSONValue
    let context: KeywordContext
    private let referenceURI: String

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.referenceURI = value.string ?? ""
    }

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context, baseURI: URL?) throws(ValidationIssue) {
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
        let result = cachedSchema.validate(input, at: self.context.location)
        if !result.valid {
          throw .referenceValidationFailure(ref: referenceURI, errors: result.errors ?? [])
        }
        return
      }

      guard let resolvedSchema = try resolveSchema(from: referenceURI, at: self.context.location, context: context, baseURI: baseURI) else {
        throw .invalidReference("Unable to resolve $ref '\(referenceURI)' at \(instanceLocation)")
      }

      // Update cache
      context.schemaCache[referenceURI] = resolvedSchema

      let result = resolvedSchema.validate(input, at: instanceLocation)
      if !result.valid {
        throw .referenceValidationFailure(ref: referenceURI, errors: result.errors ?? [])
      }
    }

    private func resolveSchema(from referenceURI: String, at instanceLocation: JSONPointer, context: Context, baseURI: URL?) throws(ValidationIssue) -> Schema? {
      guard let resolvedURI = URL(string: referenceURI, relativeTo: baseURI)?.absoluteURL else {
        throw ValidationIssue.invalidReference("Invalid $ref URI '\(referenceURI)' at \(instanceLocation)")
      }

      if context.dialect.rawValue == resolvedURI.absoluteString {
        do {
          return try context.dialect.loadMetaSchema()
        } catch {
          throw .invalidReference("Failed to create metaschema \(error)")
        }
      }

      if let schemaLocation = context.identifierRegistry[resolvedURI.absoluteURL] {
        guard let value = context.rootRawSchema?.value(at: schemaLocation.dropLast()) else {
          throw .invalidReference("Could not retrieve subschema from $id '\(resolvedURI)'")
        }

        do {
          return try Schema(rawSchema: value, location: schemaLocation, context: context, baseURI: self.context.uri)
        } catch {
          throw .invalidReference("Failed to create schema \(error)")
        }
      } else if let urlWithoutFragment = resolvedURI.withoutFragment, let rawSchema = context.remoteSchemaStorage[urlWithoutFragment.absoluteString] {
        let scopedRawSchema: JSONValue
        do {
          if let fragment = resolvedURI.fragment(percentEncoded: false) {
            guard let subRawSchema = rawSchema.value(at: JSONPointer(from: fragment)) else {
              return nil
            }
            scopedRawSchema = subRawSchema
          } else {
            scopedRawSchema = rawSchema
          }
          return try Schema(rawSchema: scopedRawSchema, location: self.context.location, context: context, baseURI: self.context.uri)
        } catch {
          throw .invalidReference("Unable to validate remote reference '\(referenceURI)' at \(instanceLocation): \(error)")
        }
      } else if resolvedURI.fragment != nil {
        guard let rootRawSchema = context.rootRawSchema else {
          print("No root raw schema for local reference")
          return nil
        }
        return try resolveInternalReference(resolvedURI, rawSchema: rootRawSchema, context: context)
      }

      return nil
    }

    func resolveInternalReference(_ uri: URL, rawSchema: JSONValue, context: Context) throws(ValidationIssue) -> Schema? {
      guard let fragment = uri.fragment(percentEncoded: false) else {
        return nil
      }

      let pointer = context.anchors[fragment]?.dropLast() ?? JSONPointer(from: fragment)
      guard let value = rawSchema.value(at: pointer) else {
        print("Failed to resolve internal reference '\(uri)' at \(self.context.location)")
        return nil
      }
      return try? Schema(rawSchema: value, location: self.context.location, context: context)
    }
  }

  struct DynamicReference: ReferenceKeyword {
    static let name = "$dynamicRef"

    let value: JSONValue
    let context: KeywordContext

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context, baseURI: URL?) throws(ValidationIssue){

    }
  }
}

extension URL {
  /// Returns the URL without the fragment part (everything before the `#`)
  var withoutFragment: URL? {
    var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
    components?.fragment = nil // Remove the fragment part
    return components?.url // Rebuild the URL without the fragment
  }
}
