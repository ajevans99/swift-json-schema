@testable import JSONSchema2

import Testing

struct KeywordTests {
  struct AssertionKeywords {
    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.boolean(true), false),
      (JSONValue.number(1), false),
      (JSONValue.null, false)
    ])
    func singleType(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = "string"
      let annotations = AnnotationContainer()
      let keyword = Keywords.TypeKeyword(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.typeMismatch) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.boolean(true), true),
      (JSONValue.number(1), false),
      (JSONValue.null, false)
    ])
    func arrayType(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["string", "boolean"]
      let annotations = AnnotationContainer()
      let keyword = Keywords.TypeKeyword(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self, "\(instance)") {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.typeMismatch) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.string("world"), false),
      (JSONValue.boolean(true), false),
      (JSONValue.number(1), true),
      (JSONValue.null, false)
    ])
    func enumKeyword(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["hello", 1]
      let annotations = AnnotationContainer()
      let keyword = Keywords.Enum(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.notEnumCase) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.string("world"), false),
      (JSONValue.boolean(true), false),
      (JSONValue.number(1), false),
      (JSONValue.null, false)
    ])
    func const(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = "hello"
      let annotations = AnnotationContainer()
      let keyword = Keywords.Constant(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.constantMismatch) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    // MARK: - Numbers

    @Test(arguments: [
      (JSONValue.number(6), true),
      (JSONValue.number(4), true),
      (JSONValue.number(5), false),
      (JSONValue.string("2"), true),
      (JSONValue.null, true)
    ])
    func multipleOf(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MultipleOf(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.notMultipleOf) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.number(5), true),
      (JSONValue.number(10), false),
      (JSONValue.integer(5), true),
      (JSONValue.integer(10), false),
      (JSONValue.string("5"), true),
      (JSONValue.null, true)
    ])
    func maximum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.Maximum(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.exceedsMaximum) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.number(4.9), true),
      (JSONValue.number(5), false),
      (JSONValue.integer(4), true),
      (JSONValue.integer(5), false),
      (JSONValue.string("4"), true),
      (JSONValue.null, true)
    ])
    func exclusiveMaximum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.ExclusiveMaximum(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.exceedsExclusiveMaximum) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.number(5), true),
      (JSONValue.number(0), false),
      (JSONValue.integer(5), true),
      (JSONValue.integer(0), false),
      (JSONValue.string("5"), true),
      (JSONValue.null, true)
    ])
    func minimum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.Minimum(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.belowMinimum) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.number(5.1), true),
      (JSONValue.number(5), false),
      (JSONValue.integer(6), true),
      (JSONValue.integer(5), false),
      (JSONValue.string("6"), true),
      (JSONValue.null, true)
    ])
    func exclusiveMinimum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.ExclusiveMinimum(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.belowExclusiveMinimum) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    // MARK: - Strings

    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.string("hello world"), false),
      (JSONValue.number(123), true),
      (JSONValue.null, true)
    ])
    func maxLength(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.MaxLength(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.exceedsMaxLength) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.string("hi"), false),
      (JSONValue.number(123), true),
      (JSONValue.null, true)
    ])
    func minLength(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 3
      let annotations = AnnotationContainer()
      let keyword = Keywords.MinLength(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.belowMinLength) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.string("hello123"), true),
      (JSONValue.string("hello"), false),
      (JSONValue.number(123), true),
      (JSONValue.null, true)
    ])
    func pattern(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = "\\d"
      let annotations = AnnotationContainer()
      let keyword = Keywords.Pattern(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.patternMismatch, "\(instance)") {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    // MARK: - Arrays

    @Test(arguments: [
      (JSONValue.array([1, 2, 3]), true),
      (JSONValue.array([1, 2, 3, 4, 5]), false),
      (JSONValue.string("not an array"), true)
    ])
    func maxItems(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 3
      let annotations = AnnotationContainer()
      let keyword = Keywords.MaxItems(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.exceedsMaxItems) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.array([1, 2, 3]), true),
      (JSONValue.array([1]), false),
      (JSONValue.string("not an array"), true)
    ])
    func minItems(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MinItems(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.belowMinItems) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.array([1, 2, 3]), true),
      (JSONValue.array([1, 1, 2]), false),
      (JSONValue.string("not an array"), true)
    ])
    func uniqueItems(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = true
      let annotations = AnnotationContainer()
      let keyword = Keywords.UniqueItems(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.itemsNotUnique) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.array([1, 2, 3]), Keywords.Contains.ContainsAnnotationValue.everyIndex, true),
      (JSONValue.array([1, 2, 3, 4, 5]), .everyIndex, false),
      (JSONValue.string("not an array"), .everyIndex, true),
      (JSONValue.array([1, 2, 3]), .indicies([0, 2]), true),
      (JSONValue.array([1, 2, 3, 4, 5]), .indicies([0, 1, 2, 3]), false),
      (JSONValue.string("not an array"), .indicies([0, 2]), true)
    ])
    func maxContains(instance: JSONValue, containsAnnotation: Keywords.Contains.ContainsAnnotationValue, isValid: Bool) {
      let schemaValue: JSONValue = 3
      let annotations = AnnotationContainer()
        .applying(containsAnnotation, to: Keywords.Contains.self)
      let keyword = Keywords.MaxContains(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.containsExcessiveMatches) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.array([1, 2, 3]), Keywords.Contains.ContainsAnnotationValue.everyIndex, true),
      (JSONValue.array([1]), .everyIndex, false),
      (JSONValue.string("not an array"), .everyIndex, true),
      (JSONValue.array([1, 2, 3]), .indicies([0, 2]), true),
      (JSONValue.array([1, 2, 3, 4, 5]), .indicies([0, 1, 2, 3]), true),
      (JSONValue.array([1, 2, 3, 4, 5]), .indicies([3]), false),
      (JSONValue.string("not an array"), .indicies([0, 2]), true)
    ])
    func minContains(instance: JSONValue, containsAnnotation: Keywords.Contains.ContainsAnnotationValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
        .applying(containsAnnotation, to: Keywords.Contains.self)
      let keyword = Keywords.MinContains(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.containsInsufficientMatches) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2]), true),
      (JSONValue.object(["a": 1, "b": 2, "c": 3]), false),
      (JSONValue.string("not an object"), true)
    ])
    func maxProperties(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MaxProperties(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.exceedsMaxProperties) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2]), true),
      (JSONValue.object(["a": 1]), false),
      (JSONValue.string("not an object"), true)
    ])
    func minProperties(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MinProperties(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.belowMinProperties) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2]), true),
      (JSONValue.object(["a": 1]), false),
      (JSONValue.object(["a": 1, "b": 2, "c": 3]), true),
      (JSONValue.string("not an object"), true)
    ])
    func required(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["a", "b"]
      let annotations = AnnotationContainer()
      let keyword = Keywords.Required(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.missingRequiredProperty(key: "b")) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2]), true),
      (JSONValue.object(["a": 1]), false),
      (JSONValue.object(["a": 1, "b": 2, "c": 3]), true),
      (JSONValue.string("not an object"), true)
    ])
    func dependentRequired(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["a": ["b"]]
      let annotations = AnnotationContainer()
      let keyword = Keywords.DependentRequired(schema: schemaValue, location: .init())

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      } else {
        #expect(throws: ValidationIssue.missingDependentProperty(key: "b", dependentOn: "a")) {
          try keyword.validate(instance, at: .init(), using: annotations)
        }
      }
    }
  }
}

extension AnnotationContainer {
  func applying<K: AnnotationProducingKeyword>(_ value: K.AnnotationValue, to keywordType: K.Type) -> Self {
    var copy = self
    copy.apply(value, to: keywordType)
    return copy
  }

  mutating func apply<K: AnnotationProducingKeyword>(_ value: K.AnnotationValue, to keywordType: K.Type) {
    self[keywordType] = .init(
      keyword: keywordType.name,
      instanceLocation: .init(),
      schemaLocation: .init(),
      value: value
    )
  }
}
