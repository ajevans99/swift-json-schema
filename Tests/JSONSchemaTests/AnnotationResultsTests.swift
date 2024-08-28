import JSONSchema
import Testing

private struct CustomAnnotationKey: AnnotationKey {
  typealias ValueType = Set<String>
}

private struct AnotherAnnotationKey: AnnotationKey {
  typealias ValueType = Int
}

private extension AnnotationResults {
  var custom: Set<String>? {
    get { self[CustomAnnotationKey.self] }
    set { self[CustomAnnotationKey.self] = newValue }
  }

  var another: Int? {
    get { self[AnotherAnnotationKey.self] }
    set { self[AnotherAnnotationKey.self] = newValue }
  }
}

struct AnnotationResultsTests {
  @Test
  func emptyState() {
    let annotationResults = AnnotationResults()
    #expect(annotationResults.custom == nil)
  }

  @Test
  func getSet() {
    var annotationResults = AnnotationResults()
    annotationResults.custom = ["foo", "bar"]
    #expect(annotationResults.custom == Set(["foo", "bar"]))
  }

  @Test
  func overwriteValue() {
    var annotationResults = AnnotationResults()
    annotationResults.custom = ["foo", "bar"]
    annotationResults.custom = ["baz"]
    #expect(annotationResults.custom == Set(["baz"]))
  }

  @Test
  func differentKeys() {
    var annotationResults = AnnotationResults()
    annotationResults.custom = ["foo"]
    annotationResults.another = 42

    #expect(annotationResults.custom == Set(["foo"]))
    #expect(annotationResults.another == 42)
  }
}
