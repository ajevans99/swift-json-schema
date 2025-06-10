public protocol KeyEncodingStrategy {
  static func encode(_ key: String) -> String
}

extension KeyEncodingStrategy {
  public static func encode(_ key: String) -> String { key }
}

public enum KeyEncodingStrategies {
  case type(any KeyEncodingStrategy.Type)

  public static var identity: Self { .type(Identity.self) }
  public static var snakeCase: Self { .type(SnakeCase.self) }
  public static func custom(_ type: any KeyEncodingStrategy.Type) -> Self { .type(type) }

  public func encode(_ key: String) -> String {
    switch self {
    case .type(let strategy):
      return strategy.encode(key)
    }
  }

  public struct Identity: KeyEncodingStrategy {}

  public struct SnakeCase: KeyEncodingStrategy {
    public static func encode(_ key: String) -> String {
      var result = ""
      for character in key {
        if character.isUppercase {
          if !result.isEmpty { result.append("_") }
          result.append(character.lowercased())
        } else {
          result.append(character)
        }
      }
      return result
    }
  }
}
