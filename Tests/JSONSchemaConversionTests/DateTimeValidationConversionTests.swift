import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct DateTimeValidationConversionTests {
  @Test(arguments: [
    "2023-05-01T12:34:56.789Z",
    "2023-05-01T18:04:56.789+05:30",
    "2023-05-01T09:04:56.789-03:30",
  ])
  func fractionalConversionWithFormatValidation(_ value: String) throws {
    let result = try Conversions.dateTime.schema.parseAndValidate(
      .string(value),
      validationContext: Context(
        dialect: .draft2020_12,
        formatValidators: DefaultFormatValidators.all
      )
    )
    #expect(result == Date(timeIntervalSince1970: 1682944496.789))
  }

  @Test func validFormatDoesNotBroadenFoundationConversion() throws {
    let context = Context(
      dialect: .draft2020_12,
      formatValidators: DefaultFormatValidators.all
    )
    let value: JSONValue = .string("2023-05-01T12:34:56Z")

    #expect(Conversions.dateTime.schema.definition(context: context).validate(value).isValid)
    #expect(throws: ParseAndValidateIssue.self) {
      try Conversions.dateTime.schema.parseAndValidate(value, validationContext: context)
    }
    let parsed = try JSONString().format("date-time")
      .parseAndValidate(
        value,
        validationContext: context
      )
    #expect(parsed == value.string)
  }
}
