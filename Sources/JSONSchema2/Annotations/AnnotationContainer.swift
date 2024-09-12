struct AnnotationContainer {
  private var storage: [ObjectIdentifier: Sendable] = [:]

  public init() {}

  public subscript<K: AnnotationProducingKeyword>(_ key: K.Type) -> Annotation<K>? {
    get { storage[ObjectIdentifier(key)] as? Annotation<K> }
    set { storage[ObjectIdentifier(key)] = newValue }
  }
}
