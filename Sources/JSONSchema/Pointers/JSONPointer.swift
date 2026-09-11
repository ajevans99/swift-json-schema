import Foundation

///  JSON Pointer defines a string syntax for identifying a specific value within a JavaScript Object Notation (JSON) document.
/// https://datatracker.ietf.org/doc/html/rfc6901
public struct JSONPointer: Sendable, Hashable {
  enum Component: Hashable {
    case index(Int)
    case key(String)
  }

  var path: [Component] = []

  public init() {}

  /// Creates a pointer, preserving each unescaped token exactly.
  ///
  /// Numeric tokens name object members when traversing objects. When traversing arrays,
  /// only `0` or an unsigned decimal index without leading zeroes can select an element.
  public init(from string: String) {
    let elements = string.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
    for element in elements {
      // https://datatracker.ietf.org/doc/html/rfc6901#section-4
      let unescaped = element.replacing("~1", with: "/").replacing("~0", with: "~")

      let component = Component.key(String(unescaped))
      if let index = component.arrayIndex {
        append(.index(index))
      } else {
        append(component)
      }
    }
  }

  init(path: [Component]) {
    self.path = path
  }

  mutating func append(_ component: Component) { path.append(component) }

  func appending(_ component: Component) -> JSONPointer {
    var pointer = self
    pointer.append(component)
    return pointer
  }

  /// Returns a new pointer created by appending the path components of another pointer.
  func appending(pointer other: JSONPointer) -> JSONPointer {
    guard !other.path.isEmpty else { return self }
    return JSONPointer(path: self.path + other.path)
  }

  func dropLast() -> JSONPointer {
    guard path.count > 0 else { return self }

    var pointer = self
    pointer.path.removeLast()
    return pointer
  }

  var isRoot: Bool { path.isEmpty }

  /// Computes the relative JSONPointer from the current pointer to a base pointer.
  ///
  /// This function compares the current ``JSONPointer`` (`self`) to the given `base` pointer. If `base` is a prefix of `self`,
  /// the function returns a new JSONPointer that represents the remaining part of `self` after `base`.
  /// If `base` is not a prefix of `self`, the function returns the original pointer.
  ///
  /// - Parameter base: The base `JSONPointer` to compare against.
  /// - Returns: A new `JSONPointer` representing the relative path from `base` to `self`. If `base` is not a prefix, `self` is returned.
  ///
  /// # Example:
  /// ```swift
  /// let basePointer: JSONPointer = "/$defs/A"
  /// let fullPointer: JSONPointer = "/$defs/A/$defs/B"
  /// let relativePointer = fullPointer.relative(toBase: basePointer)
  /// print(relativePointer) // Output: "#/$defs/B"
  /// ```
  func relative(toBase base: JSONPointer) -> JSONPointer {
    guard self.path.count >= base.path.count else {
      return self
    }

    for (selfComponent, baseComponent) in zip(self.path, base.path)
    where selfComponent != baseComponent {
      return self
    }

    return JSONPointer(path: Array(path.dropFirst(base.path.count)))
  }

  func absoluteLocation(relativeTo baseURL: URL) -> URL? {
    let base = baseURL.withoutFragment ?? baseURL
    var components = URLComponents(url: base, resolvingAgainstBaseURL: true)
    components?.fragment = jsonPointerString
    return components?.url
  }
}

extension JSONPointer: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self.init(from: value) }
}

extension JSONPointer {
  /// Creates a pointer from raw path components, performing the necessary escaping.
  public init(tokens: [String]) {
    self.init(from: JSONPointer.pointerString(from: tokens))
  }

  /// Builds a `#/...` fragment string from raw path components.
  public static func pointerString(from tokens: [String]) -> String {
    fragment(fromEncodedTokens: tokens.map(JSONPointer.escapeToken))
  }

  /// Escapes a single JSON Pointer token according to RFC 6901.
  public static func escapeToken(_ token: String) -> String {
    token
      .replacingOccurrences(of: "~", with: "~0")
      .replacingOccurrences(of: "/", with: "~1")
  }

  private static func fragment(fromEncodedTokens tokens: [String]) -> String {
    guard !tokens.isEmpty else { return "#" }
    return "#/" + tokens.joined(separator: "/")
  }
}

extension JSONPointer: CustomStringConvertible, CustomDebugStringConvertible {
  /// A JSON Pointer string as defined by RFC 6901 (no leading `#`).
  public var jsonPointerString: String {
    guard path.isEmpty == false else { return "" }

    return path.reduce(into: "") { partialResult, component in
      partialResult += "/"
      switch component {
      case .index(let int):
        partialResult += String(int)
      case .key(let string):
        partialResult +=
          string
          .replacingOccurrences(of: "~", with: "~0")
          .replacingOccurrences(of: "/", with: "~1")
      }
    }
  }

  public var description: String {
    "#" + jsonPointerString
  }

  public var debugDescription: String { description }
}

extension JSONPointer.Component {
  fileprivate var token: String {
    switch self {
    case .index(let index): return String(index)
    case .key(let key): return key
    }
  }

  fileprivate var arrayIndex: Int? {
    switch self {
    case .index(let index):
      return index >= 0 ? index : nil
    case .key(let key):
      guard let index = Int(key), index >= 0, String(index) == key else { return nil }
      return index
    }
  }

  // Parsed numeric tokens and object-key locations identify the same pointer.
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.token == rhs.token
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(token)
  }

  fileprivate var encodedFragment: String {
    switch self {
    case .index(let int):
      return String(int)
    case .key(let string):
      return JSONPointer.escapeToken(string)
    }
  }
}

extension JSONPointer: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    self.init(from: string)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(jsonPointerString)
  }
}

extension JSONValue {
  /// Resolves a pointer using exact object keys or RFC 6901 array indices.
  ///
  /// Returns `nil` for missing members, invalid or out-of-bounds array indices (including `-`),
  /// or traversal through a scalar value.
  public func value(at pointer: JSONPointer) -> JSONValue? {
    guard !pointer.path.isEmpty else { return self }

    var current: JSONValue = self

    for component in pointer.path {
      switch current {
      case .array(let array):
        guard let index = component.arrayIndex, array.indices.contains(index) else { return nil }
        current = array[index]
      case .object(let dictionary):
        guard let value = dictionary[component.token] else { return nil }
        current = value
      default:
        return nil
      }
    }

    return current
  }
}
