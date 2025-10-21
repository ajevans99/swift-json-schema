import Foundation
import JSONSchema
import JSONSchemaBuilder

/// A conversion for JSON Schema `date-time` format to `Foundation.Date`.
///
/// Accepts strings in ISO 8601 date-time format, e.g. "2023-05-01T12:34:56.789Z".
/// Returns a `Date` if parsing succeeds, otherwise fails validation.
public struct DateTimeConversion: Schemable {
  private static let encodingFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  public static var schema: some JSONSchemaComponent<Date> {
    JSONString()
      .format("date-time")
      .compactMap { value in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
      }
  }

  public static func encode(_ value: Date) -> JSONValue {
    .string(encodingFormatter.string(from: value))
  }
}

/// A conversion for JSON Schema `date` format to `Foundation.Date`.
///
/// Accepts strings in the format "yyyy-MM-dd" (e.g. "2023-05-01").
/// Returns a `Date` if parsing succeeds, otherwise fails validation.
public struct DateConversion: Schemable {
  private static let encodingFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  public static var schema: some JSONSchemaComponent<Date> {
    JSONString()
      .format("date")
      .compactMap { value in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
      }
  }

  public static func encode(_ value: Date) -> JSONValue {
    .string(encodingFormatter.string(from: value))
  }
}

/// A conversion for JSON Schema `time` format to `Foundation.DateComponents`.
///
/// Accepts strings in the format "hh:mm:ss(.sss)?(Z|+hh:mm)?" (e.g. "12:34:56.789Z").
/// Returns `DateComponents` if parsing succeeds, otherwise fails validation.
public struct TimeConversion: Schemable {
  private static let encodingFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withTime, .withColonSeparatorInTime, .withFractionalSeconds, .withTimeZone,
    ]
    return formatter
  }()

  private static var encodingCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }()

  public static var schema: some JSONSchemaComponent<DateComponents> {
    JSONString()
      .format("time")
      .compactMap { value -> DateComponents? in
        // Basic ISO8601 time parsing (hh:mm:ss(.sss)?(Z|+hh:mm)?)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
          .withTime, .withColonSeparatorInTime, .withFractionalSeconds, .withTimeZone,
        ]
        if let date = isoFormatter.date(from: value) {
          var calendar = Calendar(identifier: .gregorian)
          guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            return nil
          }
          calendar.timeZone = timeZone
          return calendar.dateComponents(
            [.hour, .minute, .second, .nanosecond, .timeZone],
            from: date
          )
        }
        return nil
      }
  }

  public static func encode(_ value: DateComponents) -> JSONValue {
    var components = value
    if components.timeZone == nil {
      components.timeZone = TimeZone(secondsFromGMT: 0)
    }
    guard let date = encodingCalendar.date(from: components) else {
      preconditionFailure("Unable to encode DateComponents to ISO-8601 time representation")
    }
    return .string(encodingFormatter.string(from: date))
  }
}
