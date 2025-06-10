/// A protocol that defines how string keys should be encoded.
///
/// Implementations of this protocol provide different strategies for transforming
/// string keys, such as converting between different case styles.
public protocol KeyEncodingStrategy {
  static func encode(_ key: String) -> String
}


/// A collection of key encoding strategies that can be used to transform string keys.
///
/// This type provides static access to various key encoding strategies and allows
/// for custom strategy implementations.
public struct KeyEncodingStrategies {
  private let strategy: any KeyEncodingStrategy.Type
  
  private init(_ strategy: any KeyEncodingStrategy.Type) {
    self.strategy = strategy
  }

  /// Returns a strategy that performs no transformation on the input key.
  ///
  /// Example:
  /// ```swift
  /// let strategy = KeyEncodingStrategies.identity
  /// strategy.encode("helloWorld") // "helloWorld"
  /// strategy.encode("userID") // "userID"
  /// strategy.encode("JSONSchema") // "JSONSchema"
  /// ```
  public static var identity: Self { Self(Identity.self) }
  
  /// Returns a strategy that converts camelCase to snake_case.
  ///
  /// Example:
  /// ```swift
  /// let strategy = KeyEncodingStrategies.snakeCase
  /// strategy.encode("helloWorld") // "hello_world"
  /// strategy.encode("userID") // "user_id"
  /// strategy.encode("JSONSchema") // "json_schema"
  /// strategy.encode("URLRequest") // "url_request"
  /// ```
  public static var snakeCase: Self { Self(SnakeCase.self) }
  
  /// Returns a strategy that converts to kebab-case.
  ///
  /// This strategy converts camelCase to kebab-case.
  ///
  /// Example:
  /// ```swift
  /// let strategy = KeyEncodingStrategies.kebabCase
  /// strategy.encode("helloWorld") // "hello-world"
  /// strategy.encode("userID") // "user-id"
  /// strategy.encode("JSONSchema") // "json-schema"
  /// strategy.encode("URLRequest") // "url-request"
  /// ```
  public static var kebabCase: Self { Self(KebabCase.self) }
  
  /// Returns a custom encoding strategy.
  ///
  /// - Parameter type: A type conforming to `KeyEncodingStrategy` that provides
  ///   custom key encoding behavior.
  ///
  /// Example:
  /// ```swift
  /// struct UppercaseStrategy: KeyEncodingStrategy {
  ///   static func encode(_ key: String) -> String {
  ///     key.uppercased()
  ///   }
  /// }
  /// 
  /// let strategy = KeyEncodingStrategies.custom(UppercaseStrategy.self)
  /// strategy.encode("helloWorld") // "HELLOWORLD"
  /// strategy.encode("userID") // "USERID"
  /// strategy.encode("JSONSchema") // "JSONSCHEMA"
  /// ```
  public static func custom(_ type: any KeyEncodingStrategy.Type) -> Self { Self(type) }

  /// Encodes the given key using the current strategy.
  ///
  /// - Parameter key: The string key to encode.
  /// - Returns: The encoded string key.
  public func encode(_ key: String) -> String {
    strategy.encode(key)
  }

  /// A strategy that performs no transformation on the input key.
  ///
  /// This strategy simply returns the input key unchanged.
  public struct Identity: KeyEncodingStrategy {
    public static func encode(_ key: String) -> String { key }
  }

  /// A strategy that converts camelCase to snake_case.
  ///
  /// This strategy:
  /// - Converts uppercase letters to lowercase
  /// - Inserts underscores before uppercase letters (except at the start)
  /// - Preserves existing underscores
  /// - Handles acronyms by treating consecutive uppercase letters as a single word
  ///
  /// Examples:
  /// ```swift
  /// strategy.encode("helloWorld") // "hello_world"
  /// strategy.encode("userID") // "user_id"
  /// strategy.encode("JSONSchema") // "json_schema"
  /// strategy.encode("URLRequest") // "url_request"
  /// ```
  public struct SnakeCase: KeyEncodingStrategy {
    public static func encode(_ key: String) -> String {
      var result = ""
      var previousWasUppercase = false
      
      for (index, character) in key.enumerated() {
        let isLastCharacter = index == key.count - 1
        let nextCharacter = isLastCharacter ? nil : key[key.index(after: key.index(key.startIndex, offsetBy: index))]
        
        if character.isUppercase {
          if !result.isEmpty {
            // Add underscore if this is the start of a new word (previous was lowercase)
            // or if this is the last letter of an acronym followed by a word
            if !previousWasUppercase || (nextCharacter?.isUppercase == false) {
              result.append("_")
            }
          }
          result.append(character.lowercased())
          previousWasUppercase = true
        } else {
          result.append(character)
          previousWasUppercase = false
        }
      }
      return result
    }
  }

  /// A strategy that converts to kebab-case.
  ///
  /// This strategy:
  /// - Converts uppercase letters to lowercase
  /// - Inserts hyphens before uppercase letters (except at the start)
  /// - Converts existing underscores to hyphens
  /// - Preserves existing hyphens
  /// - Handles acronyms by treating consecutive uppercase letters as a single word
  ///
  /// Examples:
  /// ```swift
  /// strategy.encode("helloWorld") // "hello-world"
  /// strategy.encode("userID") // "user-id"
  /// strategy.encode("JSONSchema") // "json-schema"
  /// strategy.encode("URLRequest") // "url-request"
  /// ```
  public struct KebabCase: KeyEncodingStrategy {
    public static func encode(_ key: String) -> String {
      var result = ""
      var previousWasUppercase = false
      
      for (index, character) in key.enumerated() {
        let isLastCharacter = index == key.count - 1
        let nextCharacter = isLastCharacter ? nil : key[key.index(after: key.index(key.startIndex, offsetBy: index))]
        
        if character.isUppercase {
          if !result.isEmpty {
            // Add hyphen if this is the start of a new word (previous was lowercase)
            // or if this is the last letter of an acronym followed by a word
            if !previousWasUppercase || (nextCharacter?.isUppercase == false) {
              result.append("-")
            }
          }
          result.append(character.lowercased())
          previousWasUppercase = true
        } else if character == "_" {
          result.append("-")
          previousWasUppercase = false
        } else {
          result.append(character)
          previousWasUppercase = false
        }
      }
      return result
    }
  }
}
