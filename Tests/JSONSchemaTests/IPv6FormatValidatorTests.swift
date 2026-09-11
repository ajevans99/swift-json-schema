import Testing

@testable import JSONSchema

struct IPv6FormatValidatorTests {
  static let validAddresses = [
    "::",
    "::1",
    "::abcd",
    "2001:db8::1",
    "2001:DB8:0:0:8:800:200C:417A",
    "2001:DB8::8:800:200C:417A",
    "FF01::101",
    "fe80::abcd",
    "1:2:3:4:5:6:7:8",
    "0000:0000:0000:0000:0000:0000:0000:0000",
    "ffff:FFFF:ffff:FFFF:ffff:FFFF:ffff:FFFF",
    "::1:2:3:4:5:6:7",
    "1:2:3:4:5:6:7::",
    "1:2:3::4:5:6:7",
    "2001:db8::",
    "::1:80",
    "::0.0.0.0",
    "::255.255.255.255",
    "::192.0.2.1",
    "::ffff:192.0.2.1",
    "::FFFF:129.144.52.38",
    "0:0:0:0:0:0:13.1.68.3",
    "0:0:0:0:0:FFFF:129.144.52.38",
    "1:2:3:4:5:6:192.0.2.1",
    "1::d6:192.168.0.1",
    "1:2:3:4:5::192.0.2.1",
    "::1:2:3:4:5:192.0.2.1",
    "ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255",
  ]

  static let invalidAddresses = [
    "",
    ":",
    ":::",
    "::::",
    "1",
    "1234",
    "2001:db8",
    "1:2:3:4:5:6:7",
    "1:2:3:4:5:6:7:8:9",
    ":1:2:3:4:5:6:7",
    ":1:2:3:4:5:6:7:8",
    "1:2:3:4:5:6:7:",
    "1:2:3:4:5:6:7:8:",
    ":1::2",
    "1::2:",
    "1:::2",
    ":::1",
    "1:::",
    "1::2::3",
    "::1::",
    "1::2::3::4",
    "::1:2:3:4:5:6:7:8",
    "1:2:3:4:5:6:7:8::",
    "1:2:3:4::5:6:7:8",
    "12345::",
    "::12345",
    "1:2:3:4:5:6:7:12345",
    "::gggg",
    "::0x12",
    "::+1",
    "::-1",
    "::\u{0661}",
    "::\u{FF26}",
    "::1\u{0301}",
    " ::1",
    "::1 ",
    "::1\n",
    "\t::1",
    "::1\r\n",
    "::1\0",
    "::\0:1",
    "[::1]",
    "[::1]:80",
    "https://[::1]",
    "::1:65536",
    "fe80::1%eth0",
    "fe80::1%1",
    "fe80::1%25eth0",
    "2001:db8::/32",
    "192.0.2.1",
    "::ffff:192.0.2.1:80",
    "192.0.2.1::",
    "1:2:3:4:192.0.2.1::",
    "::192.0.2.1:1",
    "192.0.2.1::192.0.2.1",
    "1:2:3:4:5:192.0.2.1",
    "1:2:3:4:5:6:7:192.0.2.1",
    "1:2:3:4:5:6::192.0.2.1",
    "::1:2:3:4:5:6:192.0.2.1",
    "::256.0.2.1",
    "::192.0.2.256",
    "::192.0.2",
    "::192.0.2.1.5",
    "::192..2.1",
    "::192.0.2.",
    "::192.0.2.01",
    "::0192.0.2.1",
    "::00.0.0.0",
    "::+192.0.2.1",
    "::192.0.2.-1",
    "::192.0.ff.1",
    "::192.0x0.2.1",
    "::192.0.2.1e0",
    "::192.0.2.\u{0661}",
    "::192.16\u{09EA}.0.1",
    "::192.0.2.1\n",
    "::192.0.2.1\0",
    "ffff:ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255",
  ]

  @Test(arguments: validAddresses)
  func acceptsValidAddresses(_ address: String) throws {
    #expect(IPv6FormatValidator().validate(address))
    let schema = try schemaWithDefaultValidators()
    #expect(schema.validate(.string(address)).isValid)
  }

  @Test(arguments: invalidAddresses)
  func rejectsInvalidAddresses(_ address: String) throws {
    #expect(!IPv6FormatValidator().validate(address))
    let schema = try schemaWithDefaultValidators()
    #expect(!schema.validate(.string(address)).isValid)
  }

  @Test(arguments: 0 ..< 8)
  func compressionAtEveryPosition(_ start: Int) {
    for length in 1 ... (8 - start) {
      let leading = Array(repeating: "1", count: start).joined(separator: ":")
      let trailing = Array(repeating: "2", count: 8 - start - length).joined(separator: ":")
      let address = leading + "::" + trailing
      #expect(IPv6FormatValidator().validate(address), "\(address)")
    }
  }

  @Test func formatValidationRemainsOptIn() throws {
    let schema = try Schema(rawSchema: ["format": "ipv6"], context: .init(dialect: .draft2020_12))
    #expect(schema.validate(.string("not an IPv6 address")).isValid)
  }

  @Test func officialIPv6FormatCorpus() throws {
    let loader = FileLoader<[JSONSchemaTest]>(
      subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12/optional/format"
    )
    let groups = try #require(loader.loadFile(named: "ipv6"))
    try #require(!groups.isEmpty)

    for group in groups {
      try #require(!group.tests.isEmpty)
      let schema = try Schema(
        rawSchema: group.schema,
        context: .init(dialect: .draft2020_12, formatValidators: DefaultFormatValidators.all)
      )
      for testCase in group.tests {
        if let address = testCase.data.string {
          #expect(
            IPv6FormatValidator().validate(address) == testCase.valid,
            "\(testCase.description): \(address)"
          )
        }
        #expect(
          schema.validate(testCase.data).isValid == testCase.valid,
          "\(testCase.description): \(testCase.data)"
        )
      }
    }
  }

  private func schemaWithDefaultValidators() throws -> Schema {
    try Schema(
      rawSchema: ["format": "ipv6"],
      context: .init(dialect: .draft2020_12, formatValidators: DefaultFormatValidators.all)
    )
  }
}
