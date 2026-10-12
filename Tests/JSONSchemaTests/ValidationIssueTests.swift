import Foundation
import JSONSchema
import Testing

struct ValidationIssueTests {
  @Test func customCodeIsExtensible() {
    let code = ValidationIssue.Code("myCompany.customRule")
    let issue = ValidationIssue(code: code, message: "custom failed", payload: ["limit": .integer(3)])
    #expect(issue.code == "myCompany.customRule")
    #expect(issue.description == "custom failed")
    #expect(issue.payload["limit"] == .integer(3))
  }

  @Test func codableRoundTrip() throws {
    let issue = ValidationIssue.patternMismatch(string: "abc", pattern: "^x")
    let data = try JSONEncoder().encode(issue)
    let decoded = try JSONDecoder().decode(ValidationIssue.self, from: data)
    #expect(decoded == issue)
    #expect(decoded.code == .patternMismatch)
  }

  @Test func factoriesMatchCodes() {
    #expect(ValidationIssue.invalidPattern(pattern: "(").code == .invalidPattern)
    #expect(ValidationIssue.patternMismatch(string: "a", pattern: "b") != ValidationIssue.patternMismatch(string: "a", pattern: "c"))
  }
}
