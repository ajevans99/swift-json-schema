import Foundation

// MARK: - Date and Time

public struct DateTimeFormatValidator: FormatValidator {
  public let formatName = "date-time"
  private static let formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  public func validate(_ value: String) -> Bool {
    DateTimeFormatValidator.formatter.date(from: value) != nil
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
  private static let regex = try! Regex(
    #"^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):?[0-5]\d)?$"#
  )

  public func validate(_ value: String) -> Bool {
    value.firstMatch(of: Self.regex) != nil
  }
}

// MARK: - Network/IDs

public struct EmailFormatValidator: FormatValidator {
  public let formatName = "email"
  private static let regex = try! Regex(#"^[^@\s]+@[^@\s]+\.[^@\s]+$"#)
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct HostnameFormatValidator: FormatValidator {
  public let formatName = "hostname"
  private static let regex = try! Regex(
    #"^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(?:\.(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$"#
  )
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct IPv4FormatValidator: FormatValidator {
  public let formatName = "ipv4"
  private static let regex = try! Regex(
    #"^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$"#
  )
  public func validate(_ value: String) -> Bool { value.firstMatch(of: Self.regex) != nil }
}

public struct IPv6FormatValidator: FormatValidator {
  public let formatName = "ipv6"
  private static let regex = try! Regex(#"^(?:[A-Fa-f0-9]{1,4}:){7}[A-Fa-f0-9]{1,4}$"#)
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
