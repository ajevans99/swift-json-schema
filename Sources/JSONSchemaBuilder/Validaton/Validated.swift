// Adapted from https://github.com/pointfreeco/swift-validated
public enum Validated<A, E> {
  case valid(A)
  case invalid([E])

  static func error(_ error: E) -> Self {
    return .invalid([error])
  }

  public func map<ValueOfResult>(_ transform: (A) -> ValueOfResult) -> Validated<ValueOfResult, E> {
    switch self {
    case let .valid(value):
      return .valid(transform(value))
    case let .invalid(errors):
      return .invalid(errors)
    }
  }

  public func flatMap<ValueOfResult>(_ transform: (A) -> Validated<ValueOfResult, E>) -> Validated<ValueOfResult, E> {
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
    return .valid((repeat try valid(each validated)))
  } catch {
    var errors: [Error] = []

    for validated in repeat each validated {
      switch validated {
      case .valid:
        continue
      case .invalid(let array):
        errors.append(contentsOf: array)
      }
    }
    return .invalid(errors)
  }
}
