import Foundation

extension JSONValue {
  /// Options for ``JSONValue/serialized(options:)``.
  public struct SerializationOptions: Sendable, Hashable {
    public var prettyPrinted: Bool
    /// The string used to indent each pretty-printed level. Defaults to two
    /// spaces, matching `JSONEncoder`'s default.
    public var indent: String

    public init(prettyPrinted: Bool = false, indent: String = "  ") {
      self.prettyPrinted = prettyPrinted
      self.indent = indent
    }

    public static let compact = SerializationOptions(prettyPrinted: false)
    public static let pretty = SerializationOptions(prettyPrinted: true)
  }

  /// Serializes this value to a JSON-encoded `String`.
  ///
  /// Object keys are emitted in their stored (insertion) order, so output is
  /// fully deterministic across processes — `JSONEncoder` does not preserve
  /// insertion order for keyed containers, so use this when you need
  /// reproducible bytes (snapshot tests, generated artifacts, signed
  /// payloads). See issue #149.
  public func serialized(options: SerializationOptions = .compact) -> String {
    var out = ""
    write(to: &out, level: 0, options: options)
    return out
  }

  /// Convenience that returns the UTF-8 encoded form of ``serialized(options:)-9b8jq``.
  public func serializedData(options: SerializationOptions = .compact) -> Data {
    Data(serialized(options: options).utf8)
  }

  private func write(to out: inout String, level: Int, options: SerializationOptions) {
    switch self {
    case .null:
      out.append("null")
    case .boolean(let b):
      out.append(b ? "true" : "false")
    case .integer(let i):
      out.append(String(i))
    case .number(let d):
      out.append(JSONValue.format(double: d))
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
        element.write(to: &out, level: level + 1, options: options)
        if i < array.count - 1 {
          out.append(options.prettyPrinted ? "," : ",")
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
        value.write(to: &out, level: level + 1, options: options)
      }
      if options.prettyPrinted {
        out.append("\n")
        out.append(String(repeating: options.indent, count: level))
      }
      out.append("}")
    }
  }

  private static func format(double value: Double) -> String {
    if value.isFinite, value == value.rounded(), abs(value) < 1e16 {
      // Match JSONEncoder's "n.0" form for integral doubles.
      return "\(Int64(value)).0"
    }
    return String(value)
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
