///  JSON Pointer defines a string syntax for identifying a specific value within a JavaScript Object Notation (JSON) document.
/// https://datatracker.ietf.org/doc/html/rfc6901
public struct JSONPointer: Sendable, Hashable {
  enum Component: Hashable {
    case index(Int)
    case key(String)
  }

  var path: [Component] = []

  public init() {}

  public init(from string: String) {
    let elements = string.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
    for element in elements {
      // https://datatracker.ietf.org/doc/html/rfc6901#section-4
      let unescaped = element.replacing("~1", with: "/").replacing("~0", with: "~")

      if let int = Int(unescaped) {
        append(.index(int))
      } else {
        append(.key(String(unescaped)))
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

    for (selfComponent, baseComponent) in zip(self.path, base.path) {
      if selfComponent != baseComponent {
        return self // Return the original if paths diverge
      }
    }

    return JSONPointer(path: Array(path.dropFirst(base.path.count)))
  }
}

extension JSONPointer: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self.init(from: value) }
}

extension JSONPointer: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    path.reduce(into: "#") { partialResult, component in
      switch component {
      case .index(let int): partialResult += "/\(int)"
      case .key(let string): partialResult += "/\(string)"
      }
    }
  }

  public var debugDescription: String { description }
}

extension JSONPointer: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    self.init(from: string)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}

extension JSONValue {
  public func value(at pointer: JSONPointer) -> JSONValue? {
    guard !pointer.path.isEmpty else { return self }

    var current: JSONValue = self

    for path in pointer.path {
      switch path {
      case .index(let index):
        guard case .array(let array) = current else { return nil }
        guard array.indices.contains(index) else { return nil }
        current = array[index]
      case .key(let key):
        guard case .object(let dictionary) = current else { return nil }
        guard let value = dictionary[key] else { return nil }
        current = value
      }
    }

    return current
  }
}
