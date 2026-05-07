import Foundation

extension JSONValue {
  /// How ``JSONValue/serialized(options:)`` handles non-finite doubles
  /// (`NaN`, `+Inf`, `-Inf`), which are not representable in JSON.
  ///
  /// Mirrors `JSONEncoder.NonConformingFloatEncodingStrategy`. The default
  /// is ``throw_`` so callers cannot silently produce invalid JSON.
  public enum NonConformingFloatStrategy: Sendable, Hashable {
    /// Throw a ``SerializationError/nonConformingFloat(_:)`` when a
    /// non-finite double is encountered. The default.
    case `throw`
    /// Substitute the supplied string for `+Inf`, `-Inf`, and `NaN`. The
    /// string is emitted as a JSON string literal, matching
    /// `JSONEncoder.NonConformingFloatEncodingStrategy.convertToString`.
    case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    /// Emit `null` for any non-finite value.
    case null
  }

  /// Options for ``JSONValue/serialized(options:)``.
  public struct SerializationOptions: Sendable, Hashable {
    public var prettyPrinted: Bool
    /// The string used to indent each pretty-printed level. Defaults to two
    /// spaces, matching `JSONEncoder`'s default.
    public var indent: String
    /// How to handle `NaN`, `+Inf`, and `-Inf`. Defaults to `.throw`, which
    /// matches `JSONEncoder`'s default and prevents emitting invalid JSON.
    public var nonConformingFloatStrategy: NonConformingFloatStrategy

    public init(
      prettyPrinted: Bool = false,
      indent: String = "  ",
      nonConformingFloatStrategy: NonConformingFloatStrategy = .throw
    ) {
      self.prettyPrinted = prettyPrinted
      self.indent = indent
      self.nonConformingFloatStrategy = nonConformingFloatStrategy
    }

    public static let compact = SerializationOptions(prettyPrinted: false)
    public static let pretty = SerializationOptions(prettyPrinted: true)
  }

  /// Errors that ``JSONValue/serialized(options:)`` can throw.
  public enum SerializationError: Error, Equatable, Sendable {
    /// A `NaN` or infinite double was encountered and the active strategy
    /// is ``NonConformingFloatStrategy/throw_``.
    case nonConformingFloat(Double)
  }

  /// Serializes this value to a JSON-encoded `String`.
  ///
  /// Object keys are emitted in their stored (insertion) order, so output is
  /// fully deterministic across processes — `JSONEncoder` does not preserve
  /// insertion order for keyed containers, so use this when you need
  /// reproducible bytes (snapshot tests, generated artifacts, signed
  /// payloads). See issue #149.
  ///
  /// - Throws: ``SerializationError/nonConformingFloat(_:)`` when a non-finite
  ///   double is encountered and
  ///   ``SerializationOptions/nonConformingFloatStrategy`` is `.throw`.
  public func serialized(options: SerializationOptions = .compact) throws -> String {
    var out = ""
    try write(to: &out, level: 0, options: options)
    return out
  }

  /// UTF-8 encoded form of ``serialized(options:)``.
  public func serializedData(options: SerializationOptions = .compact) throws -> Data {
    Data(try serialized(options: options).utf8)
  }

  private func write(
    to out: inout String,
    level: Int,
    options: SerializationOptions
  ) throws {
    switch self {
    case .null:
      out.append("null")
    case .boolean(let b):
      out.append(b ? "true" : "false")
    case .integer(let i):
      out.append(String(i))
    case .number(let d):
      try JSONValue.appendNumber(d, options: options, to: &out)
    case .string(let s):
      JSONValue.appendQuoted(s, to: &out)
    case .array(let array):
      if array.isEmpty {
        out.append("[]")
        return
      }
      out.append("[")
      for (i, element) in array.enumerated() {
        if options.prettyPrinted {
          out.append("\n")
          out.append(String(repeating: options.indent, count: level + 1))
        }
        try element.write(to: &out, level: level + 1, options: options)
        if i < array.count - 1 {
          out.append(",")
        }
      }
      if options.prettyPrinted {
        out.append("\n")
        out.append(String(repeating: options.indent, count: level))
      }
      out.append("]")
    case .object(let dictionary):
      if dictionary.isEmpty {
        out.append("{}")
        return
      }
      out.append("{")
      var first = true
      for (key, value) in dictionary {
        if !first {
          out.append(",")
        }
        first = false
        if options.prettyPrinted {
          out.append("\n")
          out.append(String(repeating: options.indent, count: level + 1))
        }
        JSONValue.appendQuoted(key, to: &out)
        out.append(options.prettyPrinted ? " : " : ":")
        try value.write(to: &out, level: level + 1, options: options)
      }
      if options.prettyPrinted {
        out.append("\n")
        out.append(String(repeating: options.indent, count: level))
      }
      out.append("}")
    }
  }

  private static func appendNumber(
    _ value: Double,
    options: SerializationOptions,
    to out: inout String
  ) throws {
    guard value.isFinite else {
      switch options.nonConformingFloatStrategy {
      case .throw:
        throw SerializationError.nonConformingFloat(value)
      case .null:
        out.append("null")
      case .convertToString(let pos, let neg, let nan):
        let replacement: String
        if value.isNaN {
          replacement = nan
        } else if value > 0 {
          replacement = pos
        } else {
          replacement = neg
        }
        appendQuoted(replacement, to: &out)
      }
      return
    }
    if value == value.rounded(), abs(value) < 1e16 {
      // Match JSONEncoder's "n.0" form for integral doubles.
      out.append("\(Int64(value)).0")
    } else {
      out.append(String(value))
    }
  }

  private static func appendQuoted(_ string: String, to out: inout String) {
    out.append("\"")
    for scalar in string.unicodeScalars {
      switch scalar {
      case "\"":
        out.append("\\\"")
      case "\\":
        out.append("\\\\")
      case "\n":
        out.append("\\n")
      case "\r":
        out.append("\\r")
      case "\t":
        out.append("\\t")
      case "\u{08}":
        out.append("\\b")
      case "\u{0C}":
        out.append("\\f")
      default:
        if scalar.value < 0x20 {
          out.append(String(format: "\\u%04x", scalar.value))
        } else {
          out.append(Character(scalar))
        }
      }
    }
    out.append("\"")
  }
}
