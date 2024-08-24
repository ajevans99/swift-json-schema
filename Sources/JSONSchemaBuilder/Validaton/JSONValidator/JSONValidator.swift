/// A container for the library provided ``Validator``.
public enum JSONValidator {
  /// Standard JSON validator.
  public static let `default` = DefaultValidator()
  /// Validator that only validates types and ignores most type specific options like `minimum` or `multipleOf` on numbers.
  public static let typeOnly = TypeOnlyValidator()
}
