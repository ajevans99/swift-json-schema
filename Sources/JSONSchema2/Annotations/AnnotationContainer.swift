struct AnnotationContainer {
  private var storage: [ObjectIdentifier: Sendable] = [:]

  public init() {}

  public subscript<K: AnnotationProducingKeyword>(_ key: K.Type) -> Annotation<K.AnnotationValue>? {
    get { storage[ObjectIdentifier(key)] as? Annotation<K.AnnotationValue> }
    set { storage[ObjectIdentifier(key)] = newValue }
  }
}
