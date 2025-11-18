import Foundation

/// A small utility for converting arbitrary Swift type names into valid JSON Schema anchor strings.
///
/// JSON Schema anchor names must match the regular expression `[A-Za-z_][A-Za-z0-9_\-\.]*`.
public enum SchemaAnchorName {
  private static let allowedCharacters: CharacterSet = {
    var set = CharacterSet()
    set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._:/")
    return set
  }()

  private static let fallback = "_Anchor"

  public static func sanitized(_ rawValue: String) -> String {
    Self.sanitize(rawValue)
  }

  private static func sanitize(_ rawValue: String) -> String {
    var transformed = rawValue.unicodeScalars.map { scalar -> Character in
      guard allowedCharacters.contains(scalar) else {
        return "_"
      }
      return Character(scalar)
    }

    if transformed.first?.isNumber == true || transformed.first == "-" || transformed.first == "." {
      transformed.insert("_", at: 0)
    }

    if transformed.isEmpty {
      transformed = Array(fallback)
    }

    return String(transformed)
  }
}
