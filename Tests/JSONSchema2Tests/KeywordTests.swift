import Foundation
import Testing

@testable import JSONSchema2

struct KeywordTests {
  struct AssertionKeywords {
    @Test(arguments: [
      (JSONValue.string("hello"), true),
      (JSONValue.boolean(true), false),
      (JSONValue.number(1), false),
      (JSONValue.null, false),
    ])
    func singleType(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = "string"
      let annotations = AnnotationContainer()
      let keyword = Keywords.TypeKeyword(value: schemaValue)

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
      (JSONValue.null, false),
    ])
    func arrayType(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["string", "boolean"]
      let annotations = AnnotationContainer()
      let keyword = Keywords.TypeKeyword(value: schemaValue)

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
      (JSONValue.null, false),
    ])
    func enumKeyword(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["hello", 1]
      let annotations = AnnotationContainer()
      let keyword = Keywords.Enum(value: schemaValue)

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
      (JSONValue.null, false),
    ])
    func const(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = "hello"
      let annotations = AnnotationContainer()
      let keyword = Keywords.Constant(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func multipleOf(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MultipleOf(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func maximum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.Maximum(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func exclusiveMaximum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.ExclusiveMaximum(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func minimum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.Minimum(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func exclusiveMinimum(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.ExclusiveMinimum(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func maxLength(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 5
      let annotations = AnnotationContainer()
      let keyword = Keywords.MaxLength(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func minLength(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 3
      let annotations = AnnotationContainer()
      let keyword = Keywords.MinLength(value: schemaValue)

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
      (JSONValue.null, true),
    ])
    func pattern(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = "\\d"
      let annotations = AnnotationContainer()
      let keyword = Keywords.Pattern(value: schemaValue)

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
      (JSONValue.string("not an array"), true),
    ])
    func maxItems(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 3
      let annotations = AnnotationContainer()
      let keyword = Keywords.MaxItems(value: schemaValue)

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
      (JSONValue.string("not an array"), true),
    ])
    func minItems(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MinItems(value: schemaValue)

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
      (JSONValue.string("not an array"), true),
    ])
    func uniqueItems(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = true
      let annotations = AnnotationContainer()
      let keyword = Keywords.UniqueItems(value: schemaValue)

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
      (JSONValue.string("not an array"), .indicies([0, 2]), true),
    ])
    func maxContains(
      instance: JSONValue,
      containsAnnotation: Keywords.Contains.ContainsAnnotationValue,
      isValid: Bool
    ) {
      let schemaValue: JSONValue = 3
      let annotations = AnnotationContainer()
        .applying(containsAnnotation, to: Keywords.Contains.self)
      let keyword = Keywords.MaxContains(value: schemaValue)

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
      (JSONValue.string("not an array"), .indicies([0, 2]), true),
    ])
    func minContains(
      instance: JSONValue,
      containsAnnotation: Keywords.Contains.ContainsAnnotationValue,
      isValid: Bool
    ) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
        .applying(containsAnnotation, to: Keywords.Contains.self)
      let keyword = Keywords.MinContains(value: schemaValue)

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
      (JSONValue.string("not an object"), true),
    ])
    func maxProperties(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MaxProperties(value: schemaValue)

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
      (JSONValue.string("not an object"), true),
    ])
    func minProperties(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = 2
      let annotations = AnnotationContainer()
      let keyword = Keywords.MinProperties(value: schemaValue)

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
      (JSONValue.string("not an object"), true),
    ])
    func required(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["a", "b"]
      let annotations = AnnotationContainer()
      let keyword = Keywords.Required(value: schemaValue)

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
      (JSONValue.string("not an object"), true),
    ])
    func dependentRequired(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["a": ["b"]]
      let annotations = AnnotationContainer()
      let keyword = Keywords.DependentRequired(value: schemaValue)

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

  struct ApplicatorKeywords {

    // MARK: - Arrays

    @Test(arguments: [
      (
        JSONValue.array([1, "two", 3.0]), Keywords.PrefixItems.PrefixItemsAnnoationValue.everyIndex,
        true
      ),
      (JSONValue.array([1, "two", 3.0, true]), .largestIndex(2), true),
      (JSONValue.array([1, 2, 3]), nil, false),
      (JSONValue.string("not an array"), nil, true),
    ])
    func prefixItems(
      instance: JSONValue,
      expectedAnnotation: Keywords.PrefixItems.PrefixItemsAnnoationValue?,
      isValid: Bool
    ) {
      let schemaValue: JSONValue = [
        ["type": "integer"],
        ["type": "string"],
        ["type": "number"],
      ]

      var annotations = AnnotationContainer()
      let keyword = Keywords.PrefixItems(value: schemaValue)

      if isValid {
        #expect(throws: Never.self, "\(instance)") {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
      #expect(
        annotations.annotation(for: Keywords.PrefixItems.self, at: .init())?.value
        == expectedAnnotation
      )
    }

    @Test(arguments: [
      (
        JSONValue.array(["one", "two", 3]),
        Keywords.PrefixItems.PrefixItemsAnnoationValue.largestIndex(1), true
      ),
      (JSONValue.array(["one", "two", "three"]), .largestIndex(1), false),
      (JSONValue.array(["one", "two", "three"]), .everyIndex, true),
      (JSONValue.array([1, "two", 3.0]), nil, false),
      (JSONValue.array([1, 2, 3]), nil, true),
      (JSONValue.string("not an array"), nil, true),
    ])
    func items(
      instance: JSONValue,
      prefixItemsAnnotaion: Keywords.PrefixItems.PrefixItemsAnnoationValue?,
      isValid: Bool
    ) {
      let schemaValue: JSONValue = ["type": "integer"]

      var annotations = AnnotationContainer()
        .applying(prefixItemsAnnotaion, to: Keywords.PrefixItems.self)
      let keyword = Keywords.Items(value: schemaValue)

      if isValid {
        #expect(throws: Never.self, "\(instance)") {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.self, "\(instance)") {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
      // Nil when invalid, true when valid
      #expect(annotations.annotation(for: Keywords.Items.self, at: .init())?.value != !isValid)
    }

    @Test(arguments: [
      (JSONValue.array([1, 2, 3]), Keywords.Contains.ContainsAnnotationValue.everyIndex, true),
      (JSONValue.array([1, "two", 3]), .indicies([0, 2]), true),
      (JSONValue.array(["one", "two", "three"]), nil, false),
      (JSONValue.string("not an array"), nil, true),
    ])
    func contains(
      instance: JSONValue,
      expectedAnnotation: Keywords.Contains.ContainsAnnotationValue?,
      isValid: Bool
    ) {
      let schemaValue: JSONValue = ["type": "integer"]

      var annotations = AnnotationContainer()
      let keyword = Keywords.Contains(value: schemaValue)

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.containsInsufficientMatches) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
      #expect(
        annotations.annotation(for: Keywords.Contains.self, at: .init())?.value
        == expectedAnnotation
      )
    }

    // MARK: - Objects

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2]), Set(["a", "b"]), true),
      (JSONValue.object(["a": 1, "b": "string"]), nil, false),
      (JSONValue.object(["a": 1]), Set(["a"]), true),
      (JSONValue.object(["b": 2]), Set(["b"]), true),
      (JSONValue.object(["c": 3]), Set([]), true),
      (JSONValue.string("not an object"), nil, true),
    ])
    func properties(instance: JSONValue, expectedAnnotation: Set<String>?, isValid: Bool) {
      let schemaValue: JSONValue = [
        "a": ["type": "integer"],
        "b": ["type": "integer"],
      ]

      var annotations = AnnotationContainer()
      let keyword = Keywords.Properties(value: schemaValue)

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
      #expect(
        annotations.annotation(for: Keywords.Properties.self, at: .init())?.value
        == expectedAnnotation
      )
    }

    @Test(arguments: [
      (JSONValue.object(["a1": 1, "b2": 2]), Set(["a1", "b2"]), true),
      (JSONValue.object(["a1": 1, "b2": "string"]), nil, false),
      (JSONValue.object(["a1": 1]), Set(["a1"]), true),
      (JSONValue.object(["b2": 2]), Set(["b2"]), true),
      (JSONValue.object(["c3": 3]), Set([]), true),
      (JSONValue.string("not an object"), nil, true),
    ])
    func patternProperties(instance: JSONValue, expectedAnnotation: Set<String>?, isValid: Bool) {
      let schemaValue: JSONValue = [
        "a\\d": ["type": "integer"],
        "b\\d": ["type": "integer"],
      ]

      var annotations = AnnotationContainer()
      let keyword = Keywords.PatternProperties(value: schemaValue)

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
      #expect(
        annotations.annotation(for: Keywords.PatternProperties.self, at: .init())?.value
        == expectedAnnotation
      )
    }

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2, "c": 3]), Set(["c"]), true),
      (JSONValue.object(["a": 1, "b": 2, "c": "string"]), nil, false),
      (JSONValue.object(["a": 1, "b": 2]), Set([]), true),
      (JSONValue.object(["c": 3]), Set(["c"]), true),
      (JSONValue.string("not an object"), nil, true),
    ])
    func additionalProperties(instance: JSONValue, expectedAnnotation: Set<String>?, isValid: Bool)
    {
      let schemaValue: JSONValue = ["type": "integer"]

      var annotations = AnnotationContainer()
      annotations.apply(["a"], to: Keywords.Properties.self)
      annotations.apply(["b"], to: Keywords.PatternProperties.self)
      let keyword = Keywords.AdditionalProperties(value: schemaValue)

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
      #expect(
        annotations.annotation(for: Keywords.AdditionalProperties.self, at: .init())?.value
        == expectedAnnotation
      )
    }

    @Test(arguments: [
      (JSONValue.object(["a": 1, "b": 2]), true),
      (JSONValue.object(["a": 1, "b": "invalid"]), true),
      (JSONValue.object(["a": 1, "b": 2, "c": 3]), true),
      (JSONValue.object(["a": 1, "0": 2]), false),
      (JSONValue.string("not an object"), true),
    ])
    func propertyNames(instance: JSONValue, isValid: Bool) {
      let schemaValue: JSONValue = ["pattern": "^[a-z]+$"]

      var annotations = AnnotationContainer()
      let keyword = Keywords.PropertyNames(value: schemaValue)

      if isValid {
        #expect(throws: Never.self) {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      } else {
        #expect(throws: ValidationIssue.self, "\(instance)") {
          try keyword.validate(instance, at: .init(), using: &annotations)
        }
      }
    }
  }
}

extension AnnotationContainer {
  func applying<K: AnnotationProducingKeyword>(
    _ value: K.AnnotationValue?,
    to keywordType: K.Type
  ) -> Self {
    guard let value else { return self }

    var copy = self
    copy.apply(value, to: keywordType)
    return copy
  }

  mutating func apply<K: AnnotationProducingKeyword>(
    _ value: K.AnnotationValue,
    to keywordType: K.Type
  ) {
    self.insert(
      Annotation<K>(
        keyword: keywordType.name,
        instanceLocation: .init(),
        schemaLocation: .init(),
        value: value
      )
    )
  }
}

extension Keyword {
  init(
    value: JSONValue,
    location: JSONPointer = .init(),
    context: Context = .init(dialect: .draft2020_12)
  ) {
    self.init(
      value: value,
      context: .init(location: location, context: context, uri: URL(fileURLWithPath: #file))
    )
  }
}
