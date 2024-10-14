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

    private var refURL: URL {
      URL(string: referenceURI, relativeTo: context.uri)?.absoluteURL ?? context.uri
    }

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context, baseURI: URL?) throws(ValidationIssue) {
      // Check for circular references
      //      if context.validationStack.last == refURL.absoluteString {
      //        throw ValidationIssue.invalidReference("Circular reference detected for $ref '\(refURL.absoluteString)' at \(instanceLocation)")
      //      }

      context.validationStack.append(refURL.absoluteString)
      defer { context.validationStack.removeLast() }

      // Attempt to retrieve the schema from cache or resolve it
      let schema: Schema
      do {
        schema = try resolveSchema(for: refURL, context: context)
      } catch let error as ValidationIssue {
        throw error
      } catch {
        throw .invalidReference("Unable to resolve schema -- \(error)")
      }

      // Validate using the resolved schema
      var refAnnotations = AnnotationContainer()
      let result = schema.validate(input, at: instanceLocation, annotations: &refAnnotations)
      if !result.valid {
        throw ValidationIssue.referenceValidationFailure(ref: refURL.absoluteString, errors: result.errors ?? [])
      }
      annotations.merge(refAnnotations)
    }

    private func resolveSchema(for refURL: URL, context: Context) throws -> Schema {
      let referenceURL = refURL.withoutFragment ?? refURL
      var fragment = refURL.fragment(percentEncoded: false)

      if refURL.scheme == "urn", let range = referenceURI.range(of: "#") {
        fragment = String(referenceURI.suffix(from: range.upperBound))
      }

      // Fetch the base schema using the abstracted method
      let baseSchema = try fetchSchema(for: referenceURL, context: context)

      if let anchorLocation = context.anchors[refURL] {
        return try resolveSchemaFragment(pointer: anchorLocation, in: baseSchema) ?? baseSchema
      }

      // If there's a fragment, resolve it within the base schema
      if let fragment, !fragment.isEmpty {
        if let schemaAfterFragment = try resolveSchemaFragment(fragment: fragment, in: baseSchema) {
          return schemaAfterFragment
        }
      }

      return baseSchema
    }

    private func fetchSchema(for referenceURL: URL, context: Context) throws -> Schema {
      // Check if the reference is a metaschema
      if context.dialect.rawValue == referenceURL.absoluteString {
        do {
          let metaSchema = try context.dialect.loadMetaSchema()
          return metaSchema
        } catch {
          throw ValidationIssue.invalidReference("Failed to create metaschema \(error)")
        }
      }

      // Check cache
      if let cachedSchema = context.schemaCache[referenceURL.absoluteString] {
        return cachedSchema
      }

      // Attempt to find the schema in the identifier registry
      if let schemaLocation = context.identifierRegistry[referenceURL] {
        guard let value = context.rootRawSchema?.value(at: schemaLocation) else {
          throw ValidationIssue.invalidReference("Could not retrieve subschema from $id '\(referenceURL)'")
        }
        let schema = try Schema(rawSchema: value, location: schemaLocation, context: context, baseURI: self.context.uri)
        context.schemaCache[referenceURL.absoluteString] = schema
        return schema
      }

      // Attempt to load remote schema
      if let rawSchema = context.remoteSchemaStorage[referenceURL.absoluteString] {
        let schema = try Schema(rawSchema: rawSchema, location: self.context.location, context: context, baseURI: referenceURL)
        // Try to use calculated uri, this helps when remote id has a different $id, meaning referenceURL != uri
        let uri = (schema.schema as? ObjectSchema)?.uri?.absoluteString ?? referenceURL.absoluteString
        context.schemaCache[uri] = schema
        return schema
      }

      // FIXME: This is a hack because Foundation URL and fragments do not play nice together.
      // For example, `urn:uuid:deadbeef-1234-00ff-ff00-4321feebdaed` relative to `#/$defs/bar`
      // becomes `urn://#/$defs/bar` in `refURL`
      if referenceURL.scheme == "urn" && (referenceURI.hasPrefix("#") || referenceURI.hasPrefix(self.context.uri.absoluteString)) {
        guard let pointer = context.identifierRegistry[self.context.uri] else {
          throw ValidationIssue.invalidReference("Could not find identifier for URN workaround")
        }
        guard let value = context.rootRawSchema?.value(at: pointer) else {
          throw ValidationIssue.invalidReference("Could not retrieve subschema from $id '\(referenceURL)' (in URN workaround)")
        }
        let schema = try Schema(rawSchema: value, location: self.context.location, context: context, baseURI: self.context.uri)
        context.schemaCache[referenceURL.absoluteString] = schema
        return schema
      }

      // If all else fails, throw an error
      throw ValidationIssue.invalidReference("Unable to resolve $ref '\(referenceURL.absoluteString)'")
    }

    // Instead of using pointer, should use URI
    // Need to store anchor as URI too
    private func resolveSchemaFragment(fragment: String, in schema: Schema) throws -> Schema? {
      let pointer = JSONPointer(from: fragment)
      return try resolveSchemaFragment(pointer: pointer, in: schema)
    }

    private func resolveSchemaFragment(pointer: JSONPointer, in schema: Schema) throws -> Schema? {
      let adjustedPointer = pointer.relative(toBase: schema.location)

      guard let objectSchema = schema.schema as? ObjectSchema else { return nil }
      guard let subRawSchema = JSONValue.object(objectSchema.schemaValue).value(at: adjustedPointer) else {
        return nil
      }
      return try Schema(rawSchema: subRawSchema, location: self.context.location, context: context.context, baseURI: refURL)
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
    var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
    components?.fragment = nil // Remove the fragment part
    return components?.url // Rebuild the URL without the fragment
  }
}
