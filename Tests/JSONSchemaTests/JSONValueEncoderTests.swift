import JSONSchema
import Testing

struct JSONValueEncoderTests {
  struct Primitives {
    let encoder = JSONValueEncoder()

    @Test
    func encodeInt() {
      let value = 42
      let result = try? encoder.encode(value)
      #expect(result == .integer(42))
    }

    @Test
    func encodeDouble() {
      let value = 3.14
      let result = try? encoder.encode(value)
      #expect(result == .number(3.14))
    }

    @Test
    func encodeString() {
      let value = "Hello, World!"
      let result = try? encoder.encode(value)
      #expect(result == .string("Hello, World!"))
    }

    @Test
    func encodeBool() {
      let value = true
      let result = try? encoder.encode(value)
      #expect(result == .boolean(true))
    }

    @Test
    func encodeNil() {
      let result = try? encoder.encode(Optional<Int>.none)
      #expect(result == .null)
    }

    @Test
    func encodeJSONValue() {
      let result = try? encoder.encode(JSONValue.number(40))
      #expect(result == 40)
    }
  }

  struct Arrays {
    let encoder = JSONValueEncoder()

    @Test
    func encodeArrayOfInts() {
      let value = [1, 2, 3]
      let result = try? encoder.encode(value)
      #expect(result == .array([.integer(1), .integer(2), .integer(3)]))
    }

    @Test
    func encodeEmptyArray() {
      let value: [Int] = []
      let result = try? encoder.encode(value)
      #expect(result == .array([]))
    }

    @Test
    func encodeMixedArray() {
      let value: [JSONValue] = [1, "two", true]
      let result = try? encoder.encode(value)
      #expect(result == .array([.integer(1), .string("two"), .boolean(true)]))
    }
  }

  struct Dictionaries {
    let encoder = JSONValueEncoder()

    @Test
    func encodeStringIntDictionary() {
      let value = ["age": 30]
      let result = try? encoder.encode(value)
      #expect(result == .object(["age": .integer(30)]))
    }

    @Test
    func encodeEmptyDictionary() {
      let value: [String: Int] = [:]
      let result = try? encoder.encode(value)
      #expect(result == .object([:]))
    }

    @Test
    func encodeNestedDictionary() {
      let value = ["person": ["name": "Alice", "age": 30]] as [String: JSONValue]
      let result = try? encoder.encode(value)
      #expect(result == .object(["person": .object(["name": .string("Alice"), "age": .integer(30)])]))
    }
  }

  struct Optionals {
    let encoder = JSONValueEncoder()

    @Test
    func encodeNonNilOptional() {
      let value: Int? = 42
      let result = try? encoder.encode(value)
      #expect(result == .integer(42))
    }

    @Test
    func encodeNilOptional() {
      let value: Int? = nil
      let result = try? encoder.encode(value)
      #expect(result == .null)
    }

    @Test
    func encodeOptionalArrayWithNil() {
      let value: [Int?] = [1, nil, 3]
      let result = try? encoder.encode(value)
      #expect(result == .array([.integer(1), .null, .integer(3)]))
    }
  }

  struct NestedStructures {
    let encoder = JSONValueEncoder()

    @Test
    func encodeNestedArray() {
      let value = [[1, 2], [3, 4]]
      let result = try? encoder.encode(value)
      #expect(result == .array([.array([.integer(1), .integer(2)]), .array([.integer(3), .integer(4)])]))
    }

    @Test
    func encodeStructWithNestedArray() {
      struct DataWrapper: Codable {
        let data: [Int]
      }

      let value = DataWrapper(data: [1, 2, 3])
      let result = try? encoder.encode(value)
      #expect(result == .object(["data": .array([.integer(1), .integer(2), .integer(3)])]))
    }
  }

  struct CustomTypes {
    let encoder = JSONValueEncoder()

    struct Person: Codable {
      let name: String
      let age: Int
    }

    @Test
    func encodeCustomType() {
      let person = Person(name: "Alice", age: 30)
      let result = try? encoder.encode(person)
      #expect(result == .object(["name": .string("Alice"), "age": .integer(30)]))
    }
  }

  struct OptionalValues {
    let encoder = JSONValueEncoder()

    @Test
    func testEncodeOptionalValue() {
      let value: Int? = 42
      let result = try? encoder.encode(value)
      #expect(result == .integer(42))
    }

    @Test
    func testEncodeNilOptionalValue() {
      let value: Int? = nil
      let result = try? encoder.encode(value)
      #expect(result == .null)
      #expect(result != .integer(0))
    }
  }

  struct ErrorHandling {
    let encoder = JSONValueEncoder()

    @Test
    func testEncodeUnsupportedType() {
      struct UnsupportedType: Encodable {
        let unsupportedValue: Never?
      }

      let result = try? encoder.encode(UnsupportedType(unsupportedValue: nil))
      #expect(result == .object([:]))
    }
  }

  struct EdgeCases {
    let encoder = JSONValueEncoder()

    @Test
    func encodeEmptyStruct() {
      struct EmptyStruct: Codable {}

      let result = try? encoder.encode(EmptyStruct())
      #expect(result == .object([:]))
    }

    @Test
    func encodeStructWithNilOptional() {
      struct OptionalWrapper: Codable {
        let value: JSONValue
      }

      let result = try? encoder.encode(OptionalWrapper(value: .null))
      #expect(result == .object(["value": .null]))
    }

    @Test
    func encodeDeeplyNestedStructures() {
      let value = [[["deep": ["nested": ["structure": 1]]]]]
      let result = try? encoder.encode(value)
      #expect(result == .array([.array([.object(["deep": .object(["nested": .object(["structure": .integer(1)])])])])]))
    }
  }

  struct ClassHierarchy {
    let encoder = JSONValueEncoder()

    class Person: Encodable {
      var name: String

      init(name: String) {
        self.name = name
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
      }

      private enum CodingKeys: String, CodingKey {
        case name
      }
    }

    class Employee: Person {
      var jobTitle: String

      init(name: String, jobTitle: String) {
        self.jobTitle = jobTitle
        super.init(name: name)
      }

      // Encoding both 'Person' and 'Employee' properties
      override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jobTitle, forKey: .jobTitle)

        // Encode the superclass properties using superEncoder
        let superEncoder = container.superEncoder(forKey: .person)
        try super.encode(to: superEncoder)
      }

      private enum CodingKeys: String, CodingKey {
        case jobTitle, person
      }
    }

    @Test
    func encodeClassWithSuperEncoder() {
      let employee = Employee(name: "Alice", jobTitle: "Engineer")
      let result = try? encoder.encode(employee)

      #expect(result == .object([
        "jobTitle": .string("Engineer"),
        "person": .object([
          "name": .string("Alice")
        ])
      ]))
    }

    @Test
    func encodeClassWithSuperEncoderAndNilValues() {
      class EmployeeWithOptionalTitle: Person {
        var jobTitle: String?

        init(name: String, jobTitle: String?) {
          self.jobTitle = jobTitle
          super.init(name: name)
        }

        override func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          try container.encodeIfPresent(jobTitle, forKey: .jobTitle)

          let superEncoder = container.superEncoder(forKey: .person)
          try super.encode(to: superEncoder)
        }

        private enum CodingKeys: String, CodingKey {
          case jobTitle, person
        }
      }

      let employee = EmployeeWithOptionalTitle(name: "Bob", jobTitle: nil)
      let result = try? encoder.encode(employee)

      #expect(result == .object([
        "jobTitle": .null,
        "person": .object([
          "name": .string("Bob")
        ])
      ]))
    }

    @Test
    func encodeClassWithMultipleInheritanceLevels() {
      class Manager: Employee {
        var department: String

        init(name: String, jobTitle: String, department: String) {
          self.department = department
          super.init(name: name, jobTitle: jobTitle)
        }

        override func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          try container.encode(department, forKey: .department)

          let superEncoder = container.superEncoder(forKey: .employee)
          try super.encode(to: superEncoder)
        }

        private enum CodingKeys: String, CodingKey {
          case department, employee
        }
      }

      let manager = Manager(name: "Carol", jobTitle: "Manager", department: "HR")
      let result = try? encoder.encode(manager)

      #expect(result == .object([
        "department": .string("HR"),
        "employee": .object([
          "jobTitle": .string("Manager"),
          "person": .object([
            "name": .string("Carol")
          ])
        ])
      ]))
    }
  }
}
