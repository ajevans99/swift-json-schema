import Foundation

// MARK: - Date and Time

/// Validates RFC 3339 syntax and calendar dates, with optional fractional seconds.
///
/// Leap seconds must fall at UTC month-end 23:59, after applying the offset.
/// Historical leap-second announcements are not checked.
public struct DateTimeFormatValidator: FormatValidator {
  public let formatName = "date-time"
  nonisolated(unsafe) private static let regex =
    #/
    ([0-9]{4})-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])[Tt]
    ([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9]|60)
    (?:\.[0-9]+)?
    (?:[Zz]|([+-])([01][0-9]|2[0-3]):([0-5][0-9]))
    /#

  public func validate(_ value: String) -> Bool {
    guard
      let match = value.wholeMatch(of: Self.regex),
      let year = Int(match.1),
      let month = Int(match.2),
      let day = Int(match.3),
      let hour = Int(match.4),
      let minute = Int(match.5),
      let second = Int(match.6)
    else { return false }

    let monthLength = Self.daysInMonth(month, year: year)
    guard day <= monthLength else { return false }
    guard second == 60 else { return true }

    var offsetMinutes = 0
    if let sign = match.7 {
      guard
        let offsetHour = match.8.flatMap({ Int($0) }),
        let offsetMinute = match.9.flatMap({ Int($0) })
      else { return false }
      offsetMinutes = (offsetHour * 60 + offsetMinute) * (sign == "-" ? -1 : 1)
    }

    let utcMinutes = hour * 60 + minute - offsetMinutes
    // An offset under 24 hours can put UTC 23:59 on this date or the previous date.
    if utcMinutes == -1 {
      return day == 1
    }
    return utcMinutes == 23 * 60 + 59 && day == monthLength
  }

  private static func daysInMonth(_ month: Int, year: Int) -> Int {
    switch month {
    case 2:
      return year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        ? 29 : 28
    case 4, 6, 9, 11:
      return 30
    default:
      return 31
    }
  }
}

public struct DateFormatValidator: FormatValidator {
  public let formatName = "date"
  private static let formatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
  }()

  public func validate(_ value: String) -> Bool {
    DateFormatValidator.formatter.date(from: value) != nil
  }
}

public struct TimeFormatValidator: FormatValidator {
  public let formatName = "time"
  nonisolated(unsafe) private static let regex = try! Regex(
    #"^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):?[0-5]\d)?$"#
  )

  public func validate(_ value: String) -> Bool {
    value.firstMatch(of: Self.regex) != nil
  }
}

// MARK: - Network/IDs

public struct EmailFormatValidator: FormatValidator {
  public let formatName = "email"
  nonisolated(unsafe) private static let regex = try! Regex(#"^[^@\s]+@[^@\s]+\.[^@\s]+$"#)
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct HostnameFormatValidator: FormatValidator {
  public let formatName = "hostname"
  nonisolated(unsafe) private static let regex = try! Regex(
    #"^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(?:\.(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$"#
  )
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct IPv4FormatValidator: FormatValidator {
  public let formatName = "ipv4"
  nonisolated(unsafe) private static let regex = try! Regex(
    #"^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$"#
  )
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct IPv6FormatValidator: FormatValidator {
  public let formatName = "ipv6"
  nonisolated(unsafe) private static let regex = try! Regex(
    #"^(?:[A-Fa-f0-9]{1,4}:){7}[A-Fa-f0-9]{1,4}$"#
  )
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct UUIDFormatValidator: FormatValidator {
  public let formatName = "uuid"
  public func validate(_ value: String) -> Bool { UUID(uuidString: value) != nil }
}

public struct URIFormatValidator: FormatValidator {
  public let formatName = "uri"
  public func validate(_ value: String) -> Bool {
    guard let url = URL(string: value) else { return false }
    return url.scheme != nil
  }
}

public struct URIReferenceFormatValidator: FormatValidator {
  public let formatName = "uri-reference"
  public func validate(_ value: String) -> Bool {
    URL(string: value) != nil
  }
}
