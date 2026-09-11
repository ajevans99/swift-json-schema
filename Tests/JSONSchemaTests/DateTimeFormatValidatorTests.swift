import Foundation
import Testing

@testable import JSONSchema

struct DateTimeFormatValidatorTests {
  @Test(arguments: [
    "2024-01-01T12:00:00Z",
    "2024-01-01T12:00:00.0Z",
    "2024-01-01T12:00:00.000Z",
    "2024-01-01T12:00:00.12345678901234567890Z",
    "2024-01-01T12:00:00+05:30",
    "2024-01-01T12:00:00.123-03:30",
    "2024-01-01T12:00:00+23:59",
    "2024-01-01T12:00:00-23:59",
    "2024-01-01T12:00:00+00:00",
    "2024-01-01T12:00:00-00:00",
    "2024-01-01t12:00:00z",
    "2024-01-01t12:00:00.123Z",
    "2024-01-01T12:00:00z",
    "0000-02-29T00:00:00Z",
    "1500-03-01T00:00:00Z",
    "1582-10-10T00:00:00Z",
    "1600-02-29T00:00:00Z",
    "2000-02-29T00:00:00Z",
    "2024-02-29T00:00:00Z",
    "9999-12-31T23:59:59Z",
    "1998-12-31T23:59:60Z",
    "1998-12-31T15:59:60.123-08:00",
    "1999-01-01T00:59:60+01:00",
    "1999-01-01T05:29:60.123456789+05:30",
    "1999-01-01T23:58:60+23:59",
    "1998-12-31T00:00:60-23:59",
    "1999-01-01T00:00:60+00:01",
    "1998-12-31T23:58:60-00:01",
    "2015-07-01t01:59:60.0+02:00",
    "2016-12-31T23:59:60-00:00",
  ])
  func validDateTimes(_ value: String) {
    #expect(DateTimeFormatValidator().validate(value))
  }

  @Test(arguments: [
    "",
    "2024-01-01",
    "12:00:00Z",
    "2024-01-01T12:00:00",
    "2024-01-01T12:00:00.123",
    "2024-01-01 12:00:00Z",
    "2024-01-01_T12:00:00Z",
    " 2024-01-01T12:00:00Z",
    "2024-01-01T12:00:00Z ",
    "2024-01-01T12:00:00Z\n",
    "2024-01-01T12:00:00Z\r\n",
    "2024-01-01T12:00:00Z\u{0}",
    "2024-01-01T12:00:00.000Zgarbage",
    "2024-01-01T12:00:00.000Z+00:00",
    "2024-01-01T12:00:00.000+00:00Z",
    "2024-01-01T12:00:00.Z",
    "2024-01-01T12:00:00,123Z",
    "2024-01-01T12:00:00.1.2Z",
    "2024-01-01T12:00:00+24:00",
    "2024-01-01T12:00:00-24:00",
    "2024-01-01T12:00:00+00:60",
    "2024-01-01T12:00:00+0000",
    "2024-01-01T12:00:00+00",
    "2024-01-01T12:00:00+0:00",
    "2024-01-01T12:00:00+00:0",
    "2024-01-01T12:00:00+00:00:00",
    "2024-01-01T12:00:00UTC",
    "2024-1-01T12:00:00Z",
    "2024-01-1T12:00:00Z",
    "2024-01-01T1:00:00Z",
    "2024-01-01T12:0:00Z",
    "2024-01-01T12:00:0Z",
    "2024-01-01T12:00Z",
    "20240101T120000Z",
    "2024-001T12:00:00Z",
    "2024-W01-1T12:00:00Z",
    "+2024-01-01T12:00:00Z",
    "-0001-01-01T12:00:00Z",
    "10000-01-01T12:00:00Z",
    "2024-00-01T12:00:00Z",
    "2024-13-01T12:00:00Z",
    "2024-01-00T12:00:00Z",
    "2024-01-32T12:00:00Z",
    "2024-04-31T12:00:00Z",
    "2024-06-31T12:00:00Z",
    "2024-09-31T12:00:00Z",
    "2024-11-31T12:00:00Z",
    "2024-02-30T12:00:00Z",
    "2023-02-29T12:00:00Z",
    "1900-02-29T12:00:00Z",
    "1500-02-29T12:00:00Z",
    "2024-01-01T24:00:00Z",
    "2024-01-01T12:60:00Z",
    "2024-01-01T12:00:61Z",
    "1998-12-31T23:58:60Z",
    "1998-12-31T22:59:60Z",
    "1998-12-31T23:59:60+01:00",
    "1998-12-30T23:59:60Z",
    "1999-01-01T23:59:60Z",
    "1999-01-01T00:59:60-01:00",
    "1999-01-02T00:59:60+01:00",
    "1999-01-01T23:59:60+23:59",
    "1998-12-31T00:01:60-23:59",
    "202\u{0664}-01-01T12:00:00Z",
    "2024-01-01T1\u{0662}:00:00Z",
    "2024-01-01T12:00:00.\u{0661}Z",
    "2024-01-01T12:00:00+0\u{0661}:00",
    "2024-01-01T12:00:00Z\u{0301}",
  ])
  func invalidDateTimes(_ value: String) {
    #expect(!DateTimeFormatValidator().validate(value))
  }

  @Test func leapSecondCalendarPositionWithoutAnnouncementLookup() {
    let validator = DateTimeFormatValidator()
    #expect(validator.validate("2024-01-31T23:59:60Z"))
    #expect(validator.validate("2024-02-29T23:59:60Z"))
    #expect(validator.validate("2023-02-28T23:59:60Z"))
    #expect(validator.validate("2024-04-30T23:59:60Z"))
    #expect(validator.validate("2024-03-01T00:59:60+01:00"))
    #expect(!validator.validate("2024-02-28T23:59:60Z"))
    #expect(!validator.validate("2024-04-29T23:59:60Z"))
  }

  @Test func officialDraft2020FormatCases() throws {
    let groups = try FileLoader<[JSONSchemaTest]>(
      subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12/optional/format"
    )
    .loadFile(named: "date-time")
    #expect(!groups.isEmpty)

    for group in groups {
      #expect(!group.tests.isEmpty)
      let schema = try Schema(
        rawSchema: group.schema,
        context: Context(
          dialect: .draft2020_12,
          formatValidators: DefaultFormatValidators.all
        )
      )
      for test in group.tests {
        #expect(schema.validate(test.data).isValid == test.valid, "\(test.description)")
        if let value = test.data.string {
          #expect(DateTimeFormatValidator().validate(value) == test.valid, "\(test.description)")
        }
      }
    }
  }

  @Test func formatValidationRemainsOptIn() throws {
    let rawSchema: JSONValue = ["type": "string", "format": "date-time"]
    let annotationOnly = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let asserted = try Schema(
      rawSchema: rawSchema,
      context: Context(
        dialect: .draft2020_12,
        formatValidators: DefaultFormatValidators.all
      )
    )

    #expect(annotationOnly.validate(.string("not-a-date-time")).isValid)
    #expect(!asserted.validate(.string("not-a-date-time")).isValid)
    #expect(asserted.validate(.string("2024-01-01T12:00:00Z")).isValid)
    #expect(asserted.validate(.string("2024-01-01T12:00:00.123+05:30")).isValid)
    #expect(!asserted.validate(.string("2024-01-01T12:00:00Ztrailing")).isValid)
  }
}
