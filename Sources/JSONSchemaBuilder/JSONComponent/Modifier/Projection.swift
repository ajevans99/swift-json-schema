import JSONSchema

extension JSONSchemaComponent {
  /// Attaches a complete validation schema without changing this component's typed parser.
  ///
  /// See ``JSONComponents/Projection`` for the supported reference and vocabulary scope.
  public func projection(
    schemaValue: SchemaValue
  ) -> JSONComponents.Projection<Self> {
    .init(upstream: self, schemaValue: schemaValue)
  }
}

extension JSONComponents {
  /// An explicit boundary between a complete validation schema and a typed parsing schema.
  ///
  /// `schemaValue` is emitted and validated unchanged. Parsing evaluates `upstream.schemaValue`
  /// separately, preserving the caller's format validators and inheriting root `$defs` through
  /// nested projections and typed references. Conflicting definitions fail rather than shadowing.
  ///
  /// The parsing bundle must be self-contained draft 2020-12, with references exclusively to
  /// `#/$defs/...` (without percent encoding). Identifiers and anchors are supported only in
  /// reference-free bundles. Dynamic references and custom vocabularies are unsupported.
  /// The legacy `$recursiveRef` and `$recursiveAnchor` keywords are inert in draft 2020-12:
  /// their raw values are preserved, not resolved or interpreted as schemas or identifiers.
  /// This does not enable draft 2019-09 recursion or support `$dynamicRef` evaluation.
  /// Standard vocabulary subsets must include core, applicator, and validation; omitted
  /// format, unevaluated, or content vocabularies must not have keywords in the bundle.
  /// Unsupported scope or schema construction is reported as ``ParseIssue/projectionFailure(reason:)``.
  ///
  /// Use `parseAndValidate` to enforce the complete schema as well as construct the Swift output.
  /// Like other components, `parse` alone does not enforce every validation constraint.
  public struct Projection<Upstream: JSONSchemaComponent>: JSONSchemaComponent {
    public typealias Output = Upstream.Output

    public var schemaValue: SchemaValue
    private let upstream: Upstream

    public init(upstream: Upstream, schemaValue: SchemaValue) {
      self.upstream = upstream
      self.schemaValue = schemaValue
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      ParsingScope.parseProjection(upstream, value: value, validationSchema: schemaValue)
    }
  }
}
