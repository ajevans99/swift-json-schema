public struct JSONPointer: Equatable {
  enum Component: Equatable {
    case index(Int)
    case key(String)
  }

  var path: [Component] = []

  public init() {}

  public init(from string: String) {
    // https://datatracker.ietf.org/doc/html/rfc6901#section-4
    let unescaped = string
      .replacing("~1", with: "/")
      .replacing("~0", with: "~")

    for element in unescaped.split(separator: "/") {
      if let int = Int(element) {
        append(.index(int))
      } else if !element.isEmpty {
        append(.key(String(element)))
      }
    }
  }

  mutating func append(_ component: Component) {
    path.append(component)
  }
}

extension JSONPointer: CustomStringConvertible {
  public var description: String {
    path.reduce(into: "") { partialResult, component in
      switch component {
      case .index(let int):
        partialResult += "/\(int)"
      case .key(let string):
        partialResult += "/\(string)"
      }
    }
  }
}

extension JSONValue {
  public func value(at pointer: JSONPointer) -> JSONValue? {
    guard !pointer.path.isEmpty else { return self }
    
//    switch pointer.path.first {
//    case .index(let index):
//      return self[index]
//    case .key(let key):
//      return self[key]
//    }
    return nil
  }
}
