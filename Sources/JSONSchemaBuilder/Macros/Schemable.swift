@attached(extension, conformances: Schemable)
@attached(member, names: named(schema), named(keyEncodingStrategy))
public macro Schemable(
  keyStrategy: KeyEncodingStrategies? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable {
  #if compiler(>=5.9)
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    associatedtype Schema: JSONSchemaComponent

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @JSONSchemaBuilder static var schema: Schema { get }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    static var keyEncodingStrategy: KeyEncodingStrategies { get }
  #endif
}

#if compiler(>=5.9)
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  extension Schemable {
    public static var keyEncodingStrategy: KeyEncodingStrategies { .identity }
  }
#endif
