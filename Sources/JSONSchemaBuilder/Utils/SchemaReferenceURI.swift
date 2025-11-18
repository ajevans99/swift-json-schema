import JSONSchema

/// Utility helpers for constructing well-formed `$ref` URIs without manually assembling strings.
public struct SchemaReferenceURI: Equatable, CustomStringConvertible {
  public enum LocalLocation {
    /// Points at a definition stored under `$defs`.
    case defs
    /// Points at the legacy `definitions` keyword for compatibility with older drafts.
    case definitions
  }

  public let rawValue: String

  public var description: String { rawValue }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Creates a URI referencing a schema stored in `$defs`/`definitions`.
  public static func definition(
    named name: String,
    location: LocalLocation = .defs
  ) -> SchemaReferenceURI {
    let container: String
    switch location {
    case .defs: container = Keywords.Defs.name
    case .definitions: container = Keywords.Definitions.name
    }

    return documentPointer(JSONPointer(tokens: [container, name]))
  }

  /// Creates a URI pointing somewhere inside the current document using a JSON Pointer.
  public static func documentPointer(_ pointer: JSONPointer) -> SchemaReferenceURI {
    SchemaReferenceURI(rawValue: pointer.description)
  }

  /// Creates a URI referencing an external schema.
  /// - Parameters:
  ///   - baseURI: The absolute or relative URL of the remote schema encoded as a string.
  ///   - pointer: Optional JSON Pointer that will be appended as a fragment.
  /// - Returns: A well-formed URI referencing the remote schema and optional location inside it.
  public static func remote(_ baseURI: String, pointer: JSONPointer? = nil) -> SchemaReferenceURI {
    guard let pointer else { return SchemaReferenceURI(rawValue: baseURI) }
    return SchemaReferenceURI(rawValue: baseURI + pointer.description)
  }
}
