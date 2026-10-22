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

  public func validate(_ value: String) -> Bool {
    // Six hextets followed by a dotted-decimal IPv4 tail is the longest form.
    guard value.utf8.count <= 45 else { return false }

    let sections = value.split(separator: "::", omittingEmptySubsequences: false)
    guard sections.count <= 2 else { return false }

    var hextetCount = 0
    for (sectionIndex, section) in sections.enumerated() where !section.isEmpty {
      let groups = section.split(separator: ":", omittingEmptySubsequences: false)
      for (groupIndex, group) in groups.enumerated() {
        if group.contains(".") {
          guard
            sectionIndex == sections.count - 1,
            groupIndex == groups.count - 1,
            Self.isIPv4Tail(group)
          else { return false }
          hextetCount += 2
        } else {
          guard
            (1 ... 4).contains(group.utf8.count),
            group.utf8.allSatisfy({
              (48 ... 57).contains($0) || (65 ... 70).contains($0) || (97 ... 102).contains($0)
            })
          else { return false }
          hextetCount += 1
        }
      }
    }

    // Compression must replace at least one of the eight 16-bit groups.
    return sections.count == 2 ? hextetCount < 8 : hextetCount == 8
  }

  private static func isIPv4Tail(_ value: Substring) -> Bool {
    let octets = value.split(separator: ".", omittingEmptySubsequences: false)
    return octets.count == 4
      && octets.allSatisfy { octet in
        guard
          (1 ... 3).contains(octet.utf8.count),
          octet.utf8.allSatisfy({ (48 ... 57).contains($0) }),
          octet.utf8.count == 1 || octet.first != "0",
          let number = Int(octet),
          number <= 255
        else { return false }
        return true
      }
  }
}

public struct UUIDFormatValidator: FormatValidator {
  public let formatName = "uuid"
  public func validate(_ value: String) -> Bool { UUID(uuidString: value) != nil }
}

public struct URIFormatValidator: FormatValidator {
  public let formatName = "uri"
  public func validate(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard
      let colon = bytes.firstIndex(of: 58),
      colon > 0,
      Self.isAlpha(bytes[0]),
      bytes[1 ..< colon].allSatisfy(Self.isSchemeCharacter)
    else { return false }

    var hierarchy = Array(bytes[(colon + 1)...])
    if let fragmentMarker = hierarchy.firstIndex(of: 35) {
      let fragment = Array(hierarchy[(fragmentMarker + 1)...])
      guard
        !fragment.contains(35),
        Self.isValidComponent(
          fragment,
          allows: {
            Self.isPChar($0) || $0 == 47 || $0 == 63
          }
        )
      else { return false }
      hierarchy = Array(hierarchy[..<fragmentMarker])
    }

    if let queryMarker = hierarchy.firstIndex(of: 63) {
      let query = Array(hierarchy[(queryMarker + 1)...])
      guard Self.isValidComponent(query, allows: { Self.isPChar($0) || $0 == 47 || $0 == 63 })
      else { return false }
      hierarchy = Array(hierarchy[..<queryMarker])
    }

    guard hierarchy.starts(with: [47, 47]) else {
      return Self.isValidComponent(hierarchy, allows: { Self.isPChar($0) || $0 == 47 })
    }

    let authorityAndPath = Array(hierarchy.dropFirst(2))
    let pathStart = authorityAndPath.firstIndex(of: 47) ?? authorityAndPath.endIndex
    let authority = Array(authorityAndPath[..<pathStart])
    let path = Array(authorityAndPath[pathStart...])
    return Self.isValidAuthority(authority)
      && Self.isValidComponent(path, allows: { Self.isPChar($0) || $0 == 47 })
  }

  private static func isValidAuthority(_ bytes: [UInt8]) -> Bool {
    let atSigns = bytes.indices.filter { bytes[$0] == 64 }
    guard atSigns.count <= 1 else { return false }

    var hostPort = bytes
    if let atSign = atSigns.first {
      let userInfo = Array(bytes[..<atSign])
      guard
        isValidComponent(
          userInfo,
          allows: {
            isUnreserved($0) || isSubDelimiter($0) || $0 == 58
          }
        )
      else { return false }
      hostPort = Array(bytes[(atSign + 1)...])
    }

    if hostPort.first == 91 {
      guard
        let closingBracket = hostPort.firstIndex(of: 93),
        isValidIPLiteral(Array(hostPort[1 ..< closingBracket]))
      else { return false }
      let port = Array(hostPort[(closingBracket + 1)...])
      return port.isEmpty || (port[0] == 58 && port.dropFirst().allSatisfy(isDigit))
    }

    guard !hostPort.contains(91), !hostPort.contains(93) else { return false }
    let colons = hostPort.indices.filter { hostPort[$0] == 58 }
    guard colons.count <= 1 else { return false }
    let host = colons.first.map { Array(hostPort[..<$0]) } ?? hostPort
    guard
      isValidComponent(host, allows: { isUnreserved($0) || isSubDelimiter($0) })
    else { return false }
    guard let colon = colons.first else { return true }
    return hostPort[(colon + 1)...].allSatisfy(isDigit)
  }

  private static func isValidIPLiteral(_ bytes: [UInt8]) -> Bool {
    let value = String(decoding: bytes, as: UTF8.self)
    if IPv6FormatValidator().validate(value) {
      return true
    }

    guard
      bytes.count > 3,
      bytes[0] == 118 || bytes[0] == 86,
      let dot = bytes.firstIndex(of: 46),
      dot > 1,
      dot < bytes.count - 1,
      bytes[1 ..< dot].allSatisfy(isHexDigit)
    else { return false }
    return bytes[(dot + 1)...]
      .allSatisfy {
        isUnreserved($0) || isSubDelimiter($0) || $0 == 58
      }
  }

  private static func isValidComponent(
    _ bytes: [UInt8],
    allows allowed: (UInt8) -> Bool
  ) -> Bool {
    var index = 0
    while index < bytes.count {
      if bytes[index] == 37 {
        guard
          index + 2 < bytes.count,
          isHexDigit(bytes[index + 1]),
          isHexDigit(bytes[index + 2])
        else { return false }
        index += 3
      } else {
        guard allowed(bytes[index]) else { return false }
        index += 1
      }
    }
    return true
  }

  private static func isPChar(_ byte: UInt8) -> Bool {
    isUnreserved(byte) || isSubDelimiter(byte) || byte == 58 || byte == 64
  }

  private static func isUnreserved(_ byte: UInt8) -> Bool {
    isAlpha(byte) || isDigit(byte) || byte == 45 || byte == 46 || byte == 95 || byte == 126
  }

  private static func isSubDelimiter(_ byte: UInt8) -> Bool {
    switch byte {
    case 33, 36, 38, 39, 40, 41, 42, 43, 44, 59, 61: true
    default: false
    }
  }

  private static func isSchemeCharacter(_ byte: UInt8) -> Bool {
    isAlpha(byte) || isDigit(byte) || byte == 43 || byte == 45 || byte == 46
  }

  private static func isAlpha(_ byte: UInt8) -> Bool {
    (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
  }

  private static func isDigit(_ byte: UInt8) -> Bool {
    (48 ... 57).contains(byte)
  }

  private static func isHexDigit(_ byte: UInt8) -> Bool {
    isDigit(byte) || (65 ... 70).contains(byte) || (97 ... 102).contains(byte)
  }
}

public struct URIReferenceFormatValidator: FormatValidator {
  public let formatName = "uri-reference"
  public func validate(_ value: String) -> Bool {
    URL(string: value) != nil
  }
}
