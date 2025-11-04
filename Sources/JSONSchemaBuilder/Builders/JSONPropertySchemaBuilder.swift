import JSONSchema

@resultBuilder public struct JSONPropertySchemaBuilder {
  public static func buildBlock() -> EmptyPropertyCollection { .init() }

  public static func buildBlock<Component: PropertyCollection>(_ component: Component) -> Component
  { component }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  public static func buildBlock<Component: JSONPropertyComponent>(
    _ component: Component
  ) -> PropertyTuple<Component> { .init(property: component) }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  public static func buildBlock<each Component: JSONPropertyComponent>(
    _ component: repeat each Component
  ) -> PropertyTuple<repeat each Component> { .init(property: (repeat each component)) }

  public static func buildOptional<Component: PropertyCollection>(
    _ component: Component?
  ) -> JSONPropertyComponents.OptionalComponent<Component> { .init(wrapped: component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    first component: TrueComponent
  ) -> JSONPropertyComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    second component: FalseComponent
  ) -> JSONPropertyComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }

  public static func buildArray<Component: PropertyCollection>(
    _ components: [Component]
  ) -> JSONPropertyComponents.PropertyArray<Component> {
    .init(components: components)
  }
}

public protocol PropertyCollection {
  associatedtype Output

  var schemaValue: SchemaValue { get }
  var requiredKeys: [String] { get }
  func validate(_ dictionary: [String: JSONValue]) -> Parsed<Output, ParseIssue>
}

public struct EmptyPropertyCollection: PropertyCollection {
  public let schemaValue: SchemaValue = .object([:])
  public let requiredKeys: [String] = []

  public func validate(_ dictionary: [String: JSONValue]) -> Parsed<Void, ParseIssue> { .valid(()) }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct PropertyTuple<each Property: JSONPropertyComponent>: PropertyCollection {
  let property: (repeat each Property)

  public var schemaValue: SchemaValue {
    var output = SchemaValue.object([:])
    #if swift(>=6)
      for property in repeat each property where !property.key.isEmpty {

        output[property.key] = .object(property.value.schemaValue)
      }
    #else
      func schemaForProperty<Prop: JSONPropertyComponent>(_ property: Prop) {
        guard !property.key.isEmpty else { return }
        output[property.key] = property.value.schemaValue.value
      }
      repeat schemaForProperty(each property)
    #endif
    return output
  }

  public var requiredKeys: [String] {
    var keys = [String]()
    #if swift(>=6)
      for property in repeat each property where property.isRequired { keys.append(property.key) }
    #else
      func addKeyIfRequired<Prop: JSONPropertyComponent>(_ property: Prop) {
        if property.isRequired { keys.append(property.key) }
      }
      repeat addKeyIfRequired(each property)
    #endif
    return keys
  }

  public func validate(
    _ dictionary: [String: JSONValue]
  ) -> Parsed<(repeat (each Property).Output), ParseIssue> {
    zip(repeat (each property).parse(dictionary))
  }
}
