import Foundation
import JSONSchemaBuilder

/// A conversion for JSON Schema `date-time` format to `Foundation.Date`.
///
/// Accepts strings in ISO 8601 date-time format, e.g. "2023-05-01T12:34:56.789Z".
/// Returns a `Date` if parsing succeeds, otherwise fails validation.
public struct DateTimeConversion: Schemable {
  public static var schema: some JSONSchemaComponent<Date> {
    JSONString()
      .format("date-time")
      .compactMap { value in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
      }
  }
}

/// A conversion for JSON Schema `date` format to `Foundation.Date`.
///
/// Accepts strings in the format "yyyy-MM-dd" (e.g. "2023-05-01").
/// Returns a `Date` if parsing succeeds, otherwise fails validation.
public struct DateConversion: Schemable {
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
}

/// A conversion for JSON Schema `time` format to `Foundation.DateComponents`.
///
/// Accepts strings in the format "hh:mm:ss(.sss)?(Z|+hh:mm)?" (e.g. "12:34:56.789Z").
/// Returns `DateComponents` if parsing succeeds, otherwise fails validation.
public struct TimeConversion: Schemable {
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
}
