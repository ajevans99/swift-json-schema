import JSONSchema

extension DefaultValidator {
  public func validate(string: String, against options: StringSchemaOptions) -> Validation<String> {
    let builder = ValidationErrorBuilder()

    let nonNegativeIntegerSchema = JSONInteger().minimum(0)

    validateOption(options.minLength, schema: nonNegativeIntegerSchema, name: "minLength", builder: builder) { minLength in
      if string.count < minLength {
        builder.addError(.string(issue: .minLength(expected: minLength), actual: string))
      }
    }

    validateOption(options.maxLength, schema: nonNegativeIntegerSchema, name: "maxLength", builder: builder) { maxLength in
      if string.count > maxLength {
        builder.addError(.string(issue: .maxLength(expected: maxLength), actual: string))
      }
    }

    let regexSchema = JSONString()
      .format("regex")
      .compactMap { pattern in
        do {
          return (pattern, try Regex(pattern))
        } catch {
          return nil
        }
      } fallback: { input in
        .string(issue: .invalidRegularExpression, actual: input)
      }

    validateOption(options.pattern, schema: regexSchema, name: "pattern", builder: builder) { pattern, regex in
      do {
        if try regex.firstMatch(in: string) == nil {
          builder.addError(.string(issue: .pattern(expected: pattern), actual: string))
        }
      } catch {
        builder.addError(.temporary("This should not happen since there are no transforms on regex (AnyRegexOutput)."))
      }
    }

    validateOption(options.format, schema: JSONString(), name: "format", builder: builder) { _ in
      // By default, format does not effect validation. It is just an annotation.
      // In the future, should provide configuartion option to enable additional assertions.
    }

    return builder.build(for: string)
  }
}
