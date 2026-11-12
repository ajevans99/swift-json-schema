import Foundation
import OrderedCollections

protocol ReferenceKeyword: CoreKeyword {
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
        schema = try resolver.resolveSchema(isDynamic: false)
      } catch let error as ValidationIssue {
        throw error
      } catch let error as ReferenceResolverError {
        throw .invalidReference(error.description)
      } catch {
        throw .invalidReference("Unable to resolve schema -- \(error)")
      }

      var refAnnotations = AnnotationContainer()
      let result = SchemaEvaluation.$referenceKeyword.withValue(Self.name) {
        schema.validate(input, at: instanceLocation, annotations: &refAnnotations)
      }
      if let evaluationErrors = result.evaluationErrors, !evaluationErrors.isEmpty {
        throw .evaluationFailed(
          errors: evaluationErrors.map {
            $0.prefixedKeywordLocation(with: self.context.location, removingBase: schema.location)
          }
        )
      }
      if !result.isValid {
        let prefixedErrors =
          result.errors?
          .map {
            $0.prefixedKeywordLocation(with: self.context.location, removingBase: schema.location)
          } ?? []
        throw ValidationIssue.referenceValidationFailure(
          ref: referenceURI,
          errors: prefixedErrors
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
        schema = try resolver.resolveSchema(isDynamic: true)
      } catch let error as ValidationIssue {
        throw error
      } catch let error as ReferenceResolverError {
        throw .invalidReference(error.description)
      } catch {
        throw .invalidReference("Unable to resolve schema -- \(error)")
      }

      var refAnnotations = AnnotationContainer()
      let result = SchemaEvaluation.$referenceKeyword.withValue(Self.name) {
        schema.validate(input, at: instanceLocation, annotations: &refAnnotations)
      }
      if let evaluationErrors = result.evaluationErrors, !evaluationErrors.isEmpty {
        throw .evaluationFailed(
          errors: evaluationErrors.map {
            $0.prefixedKeywordLocation(with: self.context.location, removingBase: schema.location)
          }
        )
      }
      if !result.isValid {
        let prefixedErrors =
          result.errors?
          .map {
            $0.prefixedKeywordLocation(with: self.context.location, removingBase: schema.location)
          } ?? []
        throw ValidationIssue.referenceValidationFailure(
          ref: referenceURI,
          errors: prefixedErrors
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

enum ReferenceResolverError: Error, CustomStringConvertible {
  case invalidReferenceURI(String)
  case metaSchemaLoadFailed(Error)
  case unresolvedReference(URL)

  var description: String {
    switch self {
    case .invalidReferenceURI(let uri):
      return "Invalid reference URI: \(uri)"
    case .metaSchemaLoadFailed(let error):
      return "Failed to load metaschema: \(error)"
    case .unresolvedReference(let url):
      return "Unable to resolve $ref '\(url.absoluteString)'"
    }
  }
}

struct ReferenceResolver {
  let context: Context
  let referenceURI: String
  let location: JSONPointer
  let baseURI: URL
  private enum InitialTarget: Sendable {
    // Local graphs are owned by storage, never by a resolver they may contain.
    case local(URL)
    // Metaschemas have independent contexts and cannot contain this resolver.
    case external(Schema)
  }

  private let initialTarget = LockIsolated<InitialTarget?>(nil)

  func resolveSchema(isDynamic: Bool) throws -> Schema {
    // Resolve the reference URI against the base URI
    guard let refURL = URL(string: referenceURI, relativeTo: baseURI)?.absoluteURL else {
      throw ReferenceResolverError.invalidReferenceURI(referenceURI)
    }

    // Share only the static target; dynamic overrides depend on the current evaluation.
    let schema = try initialTarget.withLock { cached in
      switch cached {
      case .local(let key):
        return context.referenceTarget(for: key)!.retainingContext()
      case .external(let schema):
        return schema
      case nil:
        let fresh = try context.referenceTarget(for: refURL) ?? self.schema(for: refURL)
        if fresh.context.sharesStorage(with: context) {
          context.cacheReferenceTarget(fresh, for: refURL)
          cached = .local(refURL)
        } else {
          cached = .external(fresh)
        }
        return fresh.retainingContext()
      }
    }

    if isDynamic, let fragment = refURL.fragment, !fragment.isEmpty {
      // Per JSON Schema 2020-12 §8.2.3.2, a `$dynamicRef` only triggers
      // dynamic-scope traversal if the reference's INITIAL TARGET resource
      // (the resource that `$dynamicRef` would land in when treated as a
      // regular `$ref`) also defines a matching `$dynamicAnchor`
      // ("bookending"). If not, the reference behaves like a regular `$ref`
      // to a same-named `$anchor`.
      //
      // Check the resolved target's resource so retrieval aliases use the
      // canonical `$dynamicAnchor` registrations too.
      let targetResourceURL =
        (schema.schema as? ObjectSchema)?.uri?.withoutFragment ?? refURL.withoutFragment ?? refURL
      let isBookended =
        context.documentDynamicAnchors[targetResourceURL]?[fragment] != nil
      if isBookended {
        for scope in context.dynamicScopes {
          if let entry = scope[fragment] {
            guard let document = context.documentCache[entry.document],
              let raw = document.value(at: entry.pointer)
            else {
              break
            }
            return try Schema(
              rawSchema: raw,
              location: entry.pointer,
              context: context,
              baseURI: entry.baseURI
            )
            .retainingContext()
          }
        }
      }
    }

    return schema
  }

  private func schema(for refURL: URL) throws -> Schema {
    let referenceURL = refURL.withoutFragment ?? refURL
    var fragment = refURL.fragment(percentEncoded: false)

    if refURL.scheme == "urn", let range = referenceURI.range(of: "#") {
      fragment = String(referenceURI.suffix(from: range.upperBound))
    }

    // Fetch the base schema
    let baseSchema = try fetchSchema(for: referenceURL)

    if let resolved = try resolveFragmentOrAnchor(
      for: refURL,
      fragment: fragment,
      in: baseSchema
    ) {
      return resolved
    }

    if let fragment, !fragment.isEmpty {
      throw ReferenceResolverError.unresolvedReference(refURL)
    }
    return baseSchema
  }

  private func fetchSchema(for referenceURL: URL) throws -> Schema {
    if let meta = try loadMetaSchemaIfNeeded(referenceURL) { return meta }
    if let cached = cachedSchema(for: referenceURL) { return cached }
    if let identified = try resolveIdentifier(for: referenceURL) { return identified }
    if let remote = try loadRemoteSchema(for: referenceURL) { return remote }
    if let workaround = try resolveURNWorkaround(for: referenceURL) { return workaround }
    throw ReferenceResolverError.unresolvedReference(referenceURL)
  }

  private func loadMetaSchemaIfNeeded(_ referenceURL: URL) throws -> Schema? {
    guard context.dialect.rawValue == referenceURL.absoluteString else { return nil }
    do {
      return try context.dialect.loadMetaSchema()
    } catch {
      throw ReferenceResolverError.metaSchemaLoadFailed(error)
    }
  }

  private func cachedSchema(for referenceURL: URL) -> Schema? {
    context.schemaCache[referenceURL.absoluteString]
  }

  private func resolveIdentifier(for referenceURL: URL) throws -> Schema? {
    guard let identifierLocation = context.identifierRegistry[referenceURL] else { return nil }
    guard let document = context.documentCache[identifierLocation.document],
      let value = document.value(at: identifierLocation.pointer)
    else {
      throw ReferenceResolverError.unresolvedReference(referenceURL)
    }
    let schema = try Schema(
      rawSchema: value,
      location: identifierLocation.pointer,
      context: context,
      baseURI: identifierLocation.document
    )
    context.cacheSchema(schema, at: referenceURL.absoluteString)
    return schema
  }

  private func loadRemoteSchema(for referenceURL: URL) throws -> Schema? {
    guard let rawSchema = context.remoteSchemaStorage[referenceURL.absoluteString] else {
      return nil
    }
    let schema = try Schema(
      rawSchema: rawSchema,
      location: .init(),
      context: context,
      baseURI: referenceURL
    )
    let uri = (schema.schema as? ObjectSchema)?.uri?.absoluteString ?? referenceURL.absoluteString
    context.cacheSchema(schema, at: uri)
    context.cacheSchema(schema, at: referenceURL.absoluteString)
    return schema
  }

  private func resolveURNWorkaround(for referenceURL: URL) throws -> Schema? {
    guard referenceURL.scheme == "urn",
      referenceURI.hasPrefix("#") || referenceURI.hasPrefix(baseURI.absoluteString)
    else { return nil }
    guard let identifierLocation = context.identifierRegistry[baseURI],
      let document = context.documentCache[identifierLocation.document],
      let value = document.value(at: identifierLocation.pointer)
    else {
      throw ReferenceResolverError.unresolvedReference(referenceURL)
    }
    let schema = try Schema(
      rawSchema: value,
      location: identifierLocation.pointer,
      context: context,
      baseURI: identifierLocation.document
    )
    context.cacheSchema(schema, at: referenceURL.absoluteString)
    return schema
  }

  private func resolveFragmentOrAnchor(
    for referenceURL: URL,
    fragment: String?,
    in baseSchema: Schema
  ) throws -> Schema? {
    if let anchorLocation = context.anchors[referenceURL] {
      return try resolveSchemaFragment(for: referenceURL, pointer: anchorLocation, in: baseSchema)
    }
    if let fragment, !fragment.isEmpty {
      guard fragment.hasPrefix("/") else {
        if let uri = (baseSchema.schema as? ObjectSchema)?.uri,
          var components = URLComponents(url: uri, resolvingAgainstBaseURL: true)
        {
          components.fragment = fragment
          if let canonicalURL = components.url, let anchorLocation = context.anchors[canonicalURL] {
            return try resolveSchemaFragment(
              for: canonicalURL,
              pointer: anchorLocation,
              in: baseSchema
            )
          }
        }
        throw ReferenceResolverError.unresolvedReference(referenceURL)
      }
      let pointer = baseSchema.location.appending(pointer: JSONPointer(from: fragment))
      return try resolveSchemaFragment(for: referenceURL, pointer: pointer, in: baseSchema)
    }
    return nil
  }

  private func resolveSchemaFragment(
    for referenceURL: URL,
    pointer: JSONPointer,
    in schema: Schema
  ) throws -> Schema? {
    let adjustedPointer = pointer.relative(toBase: schema.location)
    if adjustedPointer.isRoot { return schema }

    guard let objectSchema = schema.schema as? ObjectSchema else { return nil }
    var subRawSchema = JSONValue.object(
      OrderedDictionary(
        uniqueKeysWithValues: objectSchema.schemaValue.map { ($0.key, $0.value) }
      )
    )
    var targetBaseURI = objectSchema.uri ?? referenceURL
    for (index, component) in adjustedPointer.path.enumerated() {
      guard let child = subRawSchema.value(at: JSONPointer(path: [component])) else { return nil }
      subRawSchema = child
      // The starting schema has already processed its ID; the target processes
      // its own ID during construction. Only intermediate resources need rebasing.
      if index < adjustedPointer.path.count - 1,
        let identifier = child.object?["$id"]?.string,
        let resource = URL(string: identifier, relativeTo: targetBaseURI)?.absoluteURL
      {
        targetBaseURI = resource
      }
    }
    return try Schema(
      rawSchema: subRawSchema,
      location: pointer,
      context: context,
      baseURI: targetBaseURI
    )
  }
}
