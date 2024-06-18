import Testing

@testable import JSONSchema

struct SchemaEquatableTests {
  @Test func equal() {
    #expect(Schema.boolean() == Schema.boolean())
    #expect(
      Schema.array(.annotations(description: "Description"))
        == Schema.array(.annotations(description: "Description"))
    )
    #expect(
      Schema.array(.annotations(description: "Description"), .options(uniqueItems: true))
        == Schema.array(.annotations(description: "Description"), .options(uniqueItems: true))
    )
    #expect(Schema.object() == Schema.object(.annotations()))
  }

  @Test func notEquals() {
    #expect(Schema.boolean() != Schema.boolean(.annotations(title: "Title")))
    #expect(
      Schema.array(.annotations(description: "Description1"))
        != Schema.array(.annotations(description: "Description2"))
    )
    #expect(
      Schema.array(.annotations(description: "Description"), .options(uniqueItems: true))
        != Schema.array(.annotations(description: "Description"), .options())
    )
  }

  @Test func typeMismatch() {
    #expect(Schema.boolean() != Schema.array())
    #expect(Schema.boolean(.annotations(title: "")) != Schema.array(.annotations(title: "")))
    #expect(
      Schema.array(.annotations(description: "Description"), .options(uniqueItems: true))
        != Schema.boolean(.annotations(description: "Description"))
    )
  }

  @Test func inconguentOptions() {
    #expect(
      Schema(type: .object, options: nil, annotations: .annotations(), enumValues: nil)
        != Schema(
          type: .object,
          options: ObjectSchemaOptions().eraseToAnySchemaOptions(),
          annotations: .annotations(),
          enumValues: nil
        )
    )
  }
}
