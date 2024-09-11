@testable import JSONSchema2
import Testing

struct JSONPointerTests {
  @Test func emptyInit() {
    let location = JSONPointer()
    #expect(location.path == [])
  }

  @Test func initFromString() {
    let location = JSONPointer(from: "/foo/bar")
    #expect(location.path == [.key("foo"), .key("bar")])
  }
}
