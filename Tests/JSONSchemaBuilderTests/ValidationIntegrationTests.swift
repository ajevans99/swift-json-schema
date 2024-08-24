import JSONSchemaBuilder
import Testing

struct ValidationIntegrationTests {
  @Test func number() {
    let numberSchema = JSONNumber()

    #expect(numberSchema.validate(100.0) == .valid(100.0))
    #expect(numberSchema.validate("Some string") == .invalid([.typeMismatch(expected: .number, actual: "Some string")]))
  }
}
