package func compileSchemaRegex(_ pattern: String) throws -> Regex<AnyRegexOutput> {
  try Regex(pattern)
    .matchingSemantics(.unicodeScalar)
    .asciiOnlyDigits()
    .asciiOnlyWordCharacters()
}
