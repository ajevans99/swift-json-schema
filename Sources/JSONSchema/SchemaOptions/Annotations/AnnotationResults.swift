public struct AnnotationResults: Sendable {
  private var storage: [ObjectIdentifier: Sendable] = [:]

  public init() {}

  public subscript<K: AnnotationKey>(_ key: K.Type) -> K.ValueType? {
    get { storage[ObjectIdentifier(key)] as? K.ValueType }
    set { storage[ObjectIdentifier(key)] = newValue }
  }
}

public protocol AnnotationKey {
  associatedtype ValueType: Sendable
}
