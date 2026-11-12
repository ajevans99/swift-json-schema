import Foundation
import Testing

@testable import JSONSchema

struct FormatValidatorTests {
  @Test(arguments: [
    ("2024-01-01T12:00:00.000Z", true),
    ("2024-01-01T12:00:00Z", true),
  ])
  func dateTimeValidator(value: String, isValid: Bool) {
    let validator = DateTimeFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("2024-01-01", true),
    ("01-01-2024", false),
    ("2024-1-1", false),
    ("0000-02-29", true),
    ("2024-02-30", false),
  ])
  func dateValidator(value: String, isValid: Bool) {
    let validator = DateFormatValidator()
    #expect(validator.validate(value) == isValid)
  }

  @Test(arguments: [
    ("12:34:56Z", true),
    ("12:34", false),
    ("12:34:56", false),
    ("12:34:56+0100", false),
    ("12:34:56z", true),
    ("23:59:60Z", true),
    ("00:59:60+01:00", true),
    ("23:59:60+01:00", false),
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
    ("2001:db8::1", true),
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

  @Test(arguments: [
    ("foo bar", false),
    ("https://example.com/%zz", false),
    ("https://example.com/[]", false),
    ("", true),
    ("../a:b?query#fragment", true),
    ("//[::1]:8080/path", true),
    ("0:a", false),
  ])
  func strictURIReferences(value: String, isValid: Bool) {
    #expect(URIReferenceFormatValidator().validate(value) == isValid)
  }

  @Test(arguments: ["date", "time", "uri", "uri-reference"])
  func officialFormatCorpus(format: String) throws {
    let loader = try FileLoader<[JSONSchemaTest]>(
      subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12/optional/format"
    )
    let groups = try loader.loadFile(named: format)
    try #require(!groups.isEmpty)
    let validator = try #require(DefaultFormatValidators.all.first { $0.formatName == format })

    for group in groups {
      let schema = try Schema(
        rawSchema: group.schema,
        context: .init(dialect: .draft2020_12, formatValidators: DefaultFormatValidators.all)
      )
      for testCase in group.tests {
        if let value = testCase.data.string {
          #expect(
            validator.validate(value) == testCase.valid,
            "\(testCase.description): \(value)"
          )
        }
        #expect(
          schema.validate(testCase.data).isValid == testCase.valid,
          "\(testCase.description): \(testCase.data)"
        )
      }
    }
  }
}
