import Foundation

protocol ReferenceKeyword: Keyword {
  func validate(
    _ input: JSONValue,
    at instanceLocation: JSONPointer,
    using annotations: inout AnnotationContainer,
    with context: Context,
    baseURI: URL?
  ) throws(ValidationIssue)
}

extension Keywords {
  package struct Reference: ReferenceKeyword {
    package static let name = "$ref"

    package let value: JSONValue
    package let context: KeywordContext
    private let referenceURI: String
    private let resolver: ReferenceResolver

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.referenceURI = value.string ?? ""
      self.resolver = ReferenceResolver(
        context: context.context,
        referenceURI: referenceURI,
        location: context.location,
        baseURI: context.uri
      )
    }

    func validate(
      _ input: JSONValue,
      at instanceLocation: JSONPointer,
      using annotations: inout AnnotationContainer,
      with context: Context,
      baseURI: URL?
    ) throws(ValidationIssue) {
      let schema: Schema
      do {
        schema = try resolver.resolveSchema(for: referenceURI, isDynamic: false)
      } catch let error as ValidationIssue {
        throw error
      } catch {
        throw .invalidReference("Unable to resolve schema -- \(error)")
      }

      var refAnnotations = AnnotationContainer()
      let result = schema.validate(input, at: instanceLocation, annotations: &refAnnotations)
      if !result.isValid {
        throw ValidationIssue.referenceValidationFailure(
          ref: referenceURI,
          errors: result.errors ?? []
        )
      }
      annotations.merge(refAnnotations)
    }
  }

  package struct DynamicReference: ReferenceKeyword {
    package static let name = "$dynamicRef"

    package let value: JSONValue
    package let context: KeywordContext
    private let referenceURI: String
    private let resolver: ReferenceResolver

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.referenceURI = value.string ?? ""
      self.resolver = ReferenceResolver(
        context: context.context,
        referenceURI: referenceURI,
        location: context.location,
        baseURI: context.uri
      )
    }

    func validate(
      _ input: JSONValue,
      at instanceLocation: JSONPointer,
      using annotations: inout AnnotationContainer,
      with context: Context,
      baseURI: URL?
    ) throws(ValidationIssue) {
      let schema: Schema
      do {
        schema = try resolver.resolveSchema(for: referenceURI, isDynamic: true)
      } catch let error as ValidationIssue {
        throw error
      } catch {
        throw .invalidReference("Unable to resolve schema -- \(error)")
      }

      var refAnnotations = AnnotationContainer()
      let result = schema.validate(input, at: instanceLocation, annotations: &refAnnotations)
      if !result.isValid {
        throw ValidationIssue.referenceValidationFailure(
          ref: referenceURI,
          errors: result.errors ?? []
        )
      }
      annotations.merge(refAnnotations)
    }
  }
}

extension URL {
  /// Returns the URL without the fragment part (everything before the `#`)
  var withoutFragment: URL? {
    var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
    components?.fragment = nil  // Remove the fragment part
    return components?.url  // Rebuild the URL without the fragment
  }
}

struct ReferenceResolver {
  let context: Context
  let referenceURI: String
  let location: JSONPointer
  let baseURI: URL

  func resolveSchema(for refURI: String, isDynamic: Bool) throws -> Schema {
    // Resolve the reference URI against the base URI
    guard let refURL = URL(string: refURI, relativeTo: baseURI)?.absoluteURL else {
      throw ValidationIssue.invalidReference("Invalid reference URI: \(refURI)")
    }

    if isDynamic, let fragment = refURL.fragment, !fragment.isEmpty {
      let anchor = fragment
      for scope in context.dynamicScopes.reversed() {
        if let entry = scope[anchor] {
          guard let raw = context.rootRawSchema?.value(at: entry.pointer) else {
            break
          }
          return try Schema(
            rawSchema: raw,
            location: entry.pointer,
            context: context,
            baseURI: entry.baseURI
          )
        }
      }
    }

    // Fallback to regular reference resolution
    // Attempt to retrieve the schema from cache or resolve it
    let schema = try schema(for: refURL)
    return schema
  }

  private func schema(for refURL: URL) throws -> Schema {
    let referenceURL = refURL.withoutFragment ?? refURL
    var fragment = refURL.fragment(percentEncoded: false)

    if refURL.scheme == "urn", let range = referenceURI.range(of: "#") {
      fragment = String(referenceURI.suffix(from: range.upperBound))
    }

    // Fetch the base schema using the abstracted method
    let baseSchema = try fetchSchema(for: referenceURL, context: context)

    if let anchorLocation = context.anchors[refURL] {
      return try resolveSchemaFragment(for: refURL, pointer: anchorLocation, in: baseSchema)
        ?? baseSchema
    }

    // If there's a fragment, resolve it within the base schema
    if let fragment, !fragment.isEmpty {
      if let schemaAfterFragment = try resolveSchemaFragment(
        for: refURL,
        fragment: fragment,
        in: baseSchema
      ) {
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
        throw ValidationIssue.invalidReference(
          "Could not retrieve subschema from $id '\(referenceURL)'"
        )
      }
      let schema = try Schema(
        rawSchema: value,
        location: schemaLocation,
        context: context,
        baseURI: baseURI
      )
      context.schemaCache[referenceURL.absoluteString] = schema
      return schema
    }

    // Attempt to load remote schema
    if let rawSchema = context.remoteSchemaStorage[referenceURL.absoluteString] {
      let schema = try Schema(
        rawSchema: rawSchema,
        location: location,
        context: context,
        baseURI: referenceURL
      )
      // Try to use calculated uri, this helps when remote id has a different $id, meaning referenceURL != uri
      let uri = (schema.schema as? ObjectSchema)?.uri?.absoluteString ?? referenceURL.absoluteString
      context.schemaCache[uri] = schema
      return schema
    }

    // FIXME: This is a hack because Foundation URL and fragments do not play nice together.
    // For example, `urn:uuid:deadbeef-1234-00ff-ff00-4321feebdaed` relative to `#/$defs/bar`
    // becomes `urn://#/$defs/bar` in `refURL`
    if referenceURL.scheme == "urn"
      && (referenceURI.hasPrefix("#") || referenceURI.hasPrefix(baseURI.absoluteString))
    {
      guard let pointer = context.identifierRegistry[baseURI] else {
        throw ValidationIssue.invalidReference("Could not find identifier for URN workaround")
      }
      guard let value = context.rootRawSchema?.value(at: pointer) else {
        throw ValidationIssue.invalidReference(
          "Could not retrieve subschema from $id '\(referenceURL)' (in URN workaround)"
        )
      }
      let schema = try Schema(
        rawSchema: value,
        location: location,
        context: context,
        baseURI: baseURI
      )
      context.schemaCache[referenceURL.absoluteString] = schema
      return schema
    }

    // If all else fails, throw an error
    throw ValidationIssue.invalidReference(
      "Unable to resolve $ref '\(referenceURL.absoluteString)'"
    )
  }

  private func resolveSchemaFragment(
    for referenceURL: URL,
    fragment: String,
    in schema: Schema
  ) throws -> Schema? {
    let pointer = JSONPointer(from: fragment)
    return try resolveSchemaFragment(for: referenceURL, pointer: pointer, in: schema)
  }

  private func resolveSchemaFragment(
    for referenceURL: URL,
    pointer: JSONPointer,
    in schema: Schema
  ) throws -> Schema? {
    let adjustedPointer = pointer.relative(toBase: schema.location)

    guard let objectSchema = schema.schema as? ObjectSchema else { return nil }
    guard let subRawSchema = JSONValue.object(objectSchema.schemaValue).value(at: adjustedPointer)
    else {
      return nil
    }
    return try Schema(
      rawSchema: subRawSchema,
      location: location,
      context: context,
      baseURI: referenceURL
    )
  }
}
