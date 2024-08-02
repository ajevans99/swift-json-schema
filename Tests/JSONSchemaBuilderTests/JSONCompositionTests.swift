import JSONSchema
import Testing

@testable import JSONSchemaBuilder

//struct JSONCompositionTests {
//  @Test func anyOfComposition() {
//    @JSONSchemaBuilder var sample: JSONSchemaComponent {
//      JSONComposition.AnyOf {
//        JSONString()
//        JSONNumber().minimum(0)
//      }
//    }
//
//    let expectedSchema = Schema.noType(
//      composition: .anyOf([.string(), .number(.annotations(), .options(minimum: 0))])
//    )
//
//    #expect(sample.definition == expectedSchema)
//  }
//
//  @Test func allOfComposition() {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      JSONComposition.AllOf {
//        JSONString()
//        JSONNumber().maximum(10)
//      }
//    }
//
//    let expectedSchema = Schema.noType(
//      composition: .allOf([.string(), .number(.annotations(), .options(maximum: 10))])
//    )
//
//    #expect(sample.definition == expectedSchema)
//  }
//
//  @Test func oneOfComposition() {
//    @JSONSchemaBuilder var sample: JSONSchemaComponent {
//      JSONComposition.OneOf {
//        JSONString().pattern("^[a-zA-Z]+$")
//        JSONBoolean()
//      }
//    }
//
//    let expectedSchema = Schema.noType(
//      composition: .oneOf([.string(.annotations(), .options(pattern: "^[a-zA-Z]+$")), .boolean()])
//    )
//
//    #expect(sample.definition == expectedSchema)
//  }
//
//  @Test func notComposition() {
//    @JSONSchemaBuilder var sample: JSONSchemaComponent { JSONComposition.Not { JSONString() } }
//
//    let expectedSchema = Schema.noType(composition: .not(.string()))
//
//    #expect(sample.definition == expectedSchema)
//  }
//
//  @Test func annotations() {
//    @JSONSchemaBuilder var sample: JSONSchemaComponent {
//      JSONComposition.AllOf {
//        JSONString()
//        JSONNumber().maximum(10)
//      }
//      .title("Item").description("This is the description")
//    }
//
//    #expect(sample.annotations.title == "Item")
//    #expect(sample.annotations.description == "This is the description")
//  }
//}
