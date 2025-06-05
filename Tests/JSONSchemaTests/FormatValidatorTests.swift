import Foundation
import Testing

@testable import JSONSchema

struct FormatValidatorTests {
  @Test(arguments: [
    ("2024-01-01T12:00:00.000Z", true),
    ("2024-01-01T12:00:00Z", false),
  ])
  func dateTimeValidator(value: String, isValid: Bool) {
    let validator = DateTimeFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("2024-01-01", true),
    ("01-01-2024", false),
  ])
  func dateValidator(value: String, isValid: Bool) {
    let validator = DateFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("12:34:56Z", true),
    ("12:34", false),
  ])
  func timeValidator(value: String, isValid: Bool) {
    let validator = TimeFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("test@example.com", true),
    ("invalid", false),
  ])
  func emailValidator(value: String, isValid: Bool) {
    let validator = EmailFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("example.com", true),
    ("-invalid", false),
  ])
  func hostnameValidator(value: String, isValid: Bool) {
    let validator = HostnameFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("192.168.0.1", true),
    ("256.256.256.256", false),
  ])
  func ipv4Validator(value: String, isValid: Bool) {
    let validator = IPv4FormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("2001:0db8:85a3:0000:0000:8a2e:0370:7334", true),
    ("2001:db8::1", false),
  ])
  func ipv6Validator(value: String, isValid: Bool) {
    let validator = IPv6FormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("00000000-0000-0000-0000-000000000000", true),
    ("not-a-uuid", false),
  ])
  func uuidValidator(value: String, isValid: Bool) {
    let validator = UUIDFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("https://example.com", true),
    ("ht!tp://example.com", false),
  ])
  func uriValidator(value: String, isValid: Bool) {
    let validator = URIFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("foo/bar", true),
    ("ht!tp://example.com", false),
  ])
  func uriReferenceValidator(value: String, isValid: Bool) {
    let validator = URIReferenceFormatValidator()
    #expect(validator.validate(value) == isValid)
  }
}
