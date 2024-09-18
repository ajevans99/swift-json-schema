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

      if let int = Int(unescaped) { append(.index(int)) } else { append(.key(String(unescaped))) }
    }
  }

  mutating func append(_ component: Component) { path.append(component) }

  func appending(_ component: Component) -> JSONPointer {
    var pointer = self
    pointer.append(component)
    return pointer
  }

  var isRoot: Bool { path.isEmpty }
}

extension JSONPointer: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self.init(from: value) }
}

extension JSONPointer: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    path.reduce(into: "") { partialResult, component in
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
        if array.indices.contains(index) { current = array[index] }
      case .key(let key):
        guard case .object(let dictionary) = current else { return nil }
        if let value = dictionary[key] { current = value }
      }
    }

    return current
  }
}
