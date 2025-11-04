import JSONSchema

/// Style for handling null values in schemas
public enum OrNullStyle {
  /// Uses type array: {"type": ["integer", "null"]}
  /// Best for scalar primitives - produces clearer validation errors
  case type

  /// Uses oneOf composition: {"oneOf": [{"type": "integer"}, {"type": "null"}]}
  /// Required for complex types (objects, arrays, refs)
  case union
}

extension JSONSchemaComponent {
  /// Makes this component accept null values in addition to the component's type.
  /// Returns nil when null is encountered.
  ///
  /// - Parameter style: The style to use for null acceptance
  ///   - `.type`: Uses type array `["integer", "null"]` - best for primitives
  ///   - `.union`: Uses oneOf composition - required for complex types
  ///
  /// Example:
  /// ```swift
  /// JSONInteger()
  ///   .orNull(style: .type)  // Accepts integers or null, returns Int?
  /// ```
  public func orNull(style: OrNullStyle) -> JSONComponents.AnySchemaComponent<Output?> {
    switch style {
    case .type:
      return OrNullTypeComponent<Output, Self>(wrapped: self).eraseToAnySchemaComponent()
    case .union:
      return OrNullUnionComponent<Output, Self>(wrapped: self).eraseToAnySchemaComponent()
    }
  }
}

/// Implementation using type array
private struct OrNullTypeComponent<WrappedValue, Wrapped: JSONSchemaComponent>: JSONSchemaComponent
where Wrapped.Output == WrappedValue {
  typealias Output = WrappedValue?

  var wrapped: Wrapped

  public var schemaValue: SchemaValue {
    get {
      var schema = wrapped.schemaValue

      // If there's already a type keyword, convert it to an array with null
      if case .object(var obj) = schema,
        let typeValue = obj[Keywords.TypeKeyword.name]
      {

        // Convert single type to array with null
        switch typeValue {
        case .string(let typeStr):
          obj[Keywords.TypeKeyword.name] = .array([
            .string(typeStr), .string(JSONType.null.rawValue),
          ])
        case .array(var types):
          // Add null if not already present
          let nullValue = JSONValue.string(JSONType.null.rawValue)
          if !types.contains(nullValue) {
            types.append(nullValue)
          }
          obj[Keywords.TypeKeyword.name] = .array(types)
        default:
          break
        }

        schema = .object(obj)
      }

      return schema
    }
    set {
      // Not implemented - this modifier doesn't support schema value mutation
    }
  }

  public func parse(_ value: JSONValue) -> Parsed<WrappedValue?, ParseIssue> {
    // Accept null - return nil for the optional type
    if case .null = value {
      return .valid(nil)
    }
    return wrapped.parse(value).map(Optional.some)
  }
}

/// Implementation using oneOf composition
private struct OrNullUnionComponent<WrappedValue, Wrapped: JSONSchemaComponent>: JSONSchemaComponent
where Wrapped.Output == WrappedValue {
  typealias Output = WrappedValue?

  var wrapped: Wrapped

  public var schemaValue: SchemaValue {
    get {
      .object([
        Keywords.OneOf.name: .array([
          wrapped.schemaValue.value,
          JSONNull().schemaValue.value,
        ])
      ])
    }
    set {
      // Not implemented - this modifier doesn't support schema value mutation
    }
  }

  public func parse(_ value: JSONValue) -> Parsed<WrappedValue?, ParseIssue> {
    // Accept null - return nil for the optional type
    if case .null = value {
      return .valid(nil)
    }
    return wrapped.parse(value).map(Optional.some)
  }
}
