import JSONSchema

@resultBuilder public struct JSONPropertySchemaBuilder {
  public static func buildBlock() -> EmptyPropertyCollection { .init() }

  public static func buildBlock<Component: PropertyCollection>(_ component: Component) -> Component
  { component }

  public static func buildBlock<Component: JSONPropertyComponent>(
    _ component: Component
  ) -> PropertyTuple<Component> { .init(property: component) }

  public static func buildBlock<each Component: JSONPropertyComponent>(
    _ component: repeat each Component
  ) -> PropertyTuple<repeat each Component> { .init(property: (repeat each component)) }

  public static func buildOptional<Component: PropertyCollection>(
    _ component: Component?
  ) -> JSONPropertyComponents.OptionalNoType<Component> { .init(wrapped: component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    first component: TrueComponent
  ) -> JSONPropertyComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    second component: FalseComponent
  ) -> JSONPropertyComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }
}

public protocol PropertyCollection: Sendable, Equatable {
  associatedtype Output

  var schema: [String: Schema] { get }
  var requiredKeys: [String] { get }
  func validate(_ dictionary: [String: JSONValue], against validator: Validator) -> Validation<Output>
}

public struct EmptyPropertyCollection: PropertyCollection {
  public let schema: [String: Schema] = [:]
  public let requiredKeys: [String] = []

  public init() {}

  public func validate(_ dictionary: [String: JSONValue], against validator: Validator) -> Validation<Void> { .valid(()) }
}

public struct PropertyTuple<each Property: JSONPropertyComponent>: PropertyCollection {
  let property: (repeat each Property)

  public var schema: [String: Schema] {
    var output = [String: Schema]()
    #if swift(>=6)
      for property in repeat each property where !property.key.isEmpty {

        output[property.key] = property.value.definition
      }
    #else
      func schemaForProperty<Prop: JSONPropertyComponent>(_ property: Prop) {
        guard !property.key.isEmpty else { return }
        output[property.key] = property.value.definition
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
    _ dictionary: [String: JSONValue],
    against validator: Validator
  ) -> Validation<(repeat (each Property).Output)> {
    zip(repeat (each property).validate(dictionary, against: validator))
  }

  public static func == (lhs: PropertyTuple<repeat each Property>, rhs: PropertyTuple<repeat each Property>) -> Bool {
    lhs.schema == rhs.schema && lhs.requiredKeys == rhs.requiredKeys
  }
}
