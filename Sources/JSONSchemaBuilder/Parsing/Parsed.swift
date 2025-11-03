/// Similar to `Result` from Swift but `invalid` case has an array of errors.
/// Adapted from [Point-Free](https://github.com/pointfreeco/swift-validated) to use variadic parameters.
public enum Parsed<Value, Error: Swift.Error> {
  case valid(Value)
  case invalid([Error])

  static func error(_ error: Error) -> Self { .invalid([error]) }

  public func map<ValueOfResult>(
    _ transform: (Value) -> ValueOfResult
  ) -> Parsed<ValueOfResult, Error> {
    switch self {
    case .valid(let value): return .valid(transform(value))
    case .invalid(let errors): return .invalid(errors)
    }
  }

  public func flatMap<ValueOfResult>(
    _ transform: (Value) -> Parsed<ValueOfResult, Error>
  ) -> Parsed<ValueOfResult, Error> {
    switch self {
    case .valid(let value): return transform(value)
    case .invalid(let errors): return .invalid(errors)
    }
  }

  public var value: Value? {
    switch self {
    case .valid(let value): return value
    case .invalid: return nil
    }
  }

  public var errors: [Error]? {
    switch self {
    case .valid: return nil
    case .invalid(let array): return array
    }
  }
}

extension Parsed: Equatable where Value: Equatable, Error: Equatable {}

struct Invalid: Error {}

/// Combine values of Validated together into a tuple.
/// Example:
/// `zip(Parsed<A, E>, Parsed<B, E>, Parsed<C, E>)` -> `Parsed<(A, B, C), E>`
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func zip<each Value, Error>(
  _ validated: repeat Parsed<each Value, Error>
) -> Parsed<(repeat each Value), Error> {
  func valid<V>(_ v: Parsed<V, Error>) throws -> V {
    switch v {
    case .valid(let x): return x
    case .invalid:
      // Could stash errors here, but would be incomplete if invalid in
      // a middle variadic parameter. Instead fetch all errors in catch.
      throw Invalid()
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
        case .valid: continue
        case .invalid(let array): errors.append(contentsOf: array)
        }
      }
    #else
      func collectErrors<Val>(_ v: Parsed<Val, Error>) {
        switch v {
        case .valid: break
        case .invalid(let array): errors.append(contentsOf: array)
        }
      }
      repeat collectErrors(each validated)
    #endif

    return .invalid(errors)
  }
}
