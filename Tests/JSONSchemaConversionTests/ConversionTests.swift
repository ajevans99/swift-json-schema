import Foundation
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct ConversionTests {
  @Test
  func uuid() throws {
    let result = try Conversions.uuid.schema.parseAndValidate(
      "123e4567-e89b-12d3-a456-426614174000"
    )
    #expect(result == UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!)
  }

  @Test
  func dateTime() throws {
    let result = try Conversions.dateTime.schema.parseAndValidate(
      "2023-05-01T12:34:56.789Z"
    )
    let expected = ISO8601DateFormatter().date(from: "2023-05-01T12:34:56.789Z")!
    #expect(result == expected)
  }

  @Test
  func date() throws {
    let result = try Conversions.date.schema.parseAndValidate(
      "2023-05-01"
    )
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let expected = formatter.date(from: "2023-05-01")!
    #expect(result == expected)
  }

  @Test
  func time() throws {
    let result = try Conversions.time.schema.parseAndValidate(
      "12:34:56.789Z"
    )
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [
      .withTime, .withColonSeparatorInTime, .withFractionalSeconds, .withTimeZone,
    ]
    let date = isoFormatter.date(from: "1970-01-01T12:34:56.789Z")!
    let calendar = Calendar(identifier: .gregorian)
    let expected = calendar.dateComponents(
      [.hour, .minute, .second, .nanosecond, .timeZone],
      from: date
    )
    #expect(result == expected)
  }

  @Test
  func url() throws {
    let result = try Conversions.url.schema.parseAndValidate(
      "https://example.com"
    )
    #expect(result == URL(string: "https://example.com"))
  }
}
