import Foundation

public protocol FormatValidator: Sendable {
  /// The name of the format that this validator is responsible for.
  var formatName: String { get }
  /// Returns `true` if the provided string is valid for this format.
  func validate(_ value: String) -> Bool
}

public enum DefaultFormatValidators {
  /// Collection of the default validators provided by ``JSONSchema``.
  public static var all: [any FormatValidator] {
    [
      DateTimeFormatValidator(),
      DateFormatValidator(),
      TimeFormatValidator(),
      EmailFormatValidator(),
      HostnameFormatValidator(),
      IPv4FormatValidator(),
      IPv6FormatValidator(),
      UUIDFormatValidator(),
      URIFormatValidator(),
      URIReferenceFormatValidator(),
    ]
  }
}
