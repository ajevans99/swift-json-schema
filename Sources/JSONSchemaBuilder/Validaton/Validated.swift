// Adapted from https://github.com/pointfreeco/swift-validated
public enum Validated<Value, Error> {
  case valid(Value)
  case invalid([Error])

  static func error(_ error: Error) -> Self {
    return .invalid([error])
  }

  public func map<ValueOfResult>(_ transform: (Value) -> ValueOfResult) -> Validated<ValueOfResult, Error> {
    switch self {
    case let .valid(value):
      return .valid(transform(value))
    case let .invalid(errors):
      return .invalid(errors)
    }
  }

  public func flatMap<ValueOfResult>(_ transform: (Value) -> Validated<ValueOfResult, Error>) -> Validated<ValueOfResult, Error> {
    switch self {
    case let .valid(value):
      return transform(value)
    case let .invalid(errors):
      return .invalid(errors)
    }
  }
}

struct _Invalid: Error {}

public func zip<each Value, Error>(
  _ validated: repeat Validated<each Value, Error>
) -> Validated<(repeat each Value), Error> {
  func valid<V>(_ v: Validated<V, Error>) throws -> V {
    switch v {
    case .valid(let x):
      return x
    case .invalid:
      // Could stash errors here, but would be incomplete if invalid in
      // a middle variadic parameter. Instead fetch all errors in catch.
      throw _Invalid()
    }
  }

  do {
    // Compiler crash in Swift 5.10 when simply `.valid((repeat try valid(each validated)))`
    let tuple = (repeat try valid(each validated))
    return .valid(tuple)
  } catch {
    var errors: [Error] = []

#if swift(>=6)
    for validated in repeat each validated {
      switch validated {
      case .valid:
        continue
      case .invalid(let array):
        errors.append(contentsOf: array)
      }
    }
#else
    func collectErrors<Val>(_ v: Validated<Val, Error>) {
      switch v {
      case .valid:
        break
      case .invalid(let array):
        errors.append(contentsOf: array)
      }
    }
    repeat collectErrors(each validated)
#endif

    return .invalid(errors)
  }
}
