import JSONSchemaBuilder

// These "tests" are just present to fail build at compile time in case of regresssion.

@Schemable
enum TemperatureKind1 {
  case celsius
  case fahrenheit
}

@Schemable
enum TemperatureKind2 {
  case cloudy(coverage: Double)
  case rainy(chanceOfRain: Double, amount: Double)
}

@Schemable
enum TemperatureKind3 {
  case cloudy(Double)
  case rainy(chanceOfRain: Double, amount: Double?)
  case snowy
  case windy
  case stormy
}

@Schemable
private struct Weather {
  let temperature: Double = 72.0
  let units: TemperatureKind1 = .fahrenheit
  let location: String = "Detroit"
  let isRaining: Bool = false
  let windSpeed: Int = 12
  let precipitationAmount: Double? = nil
  let humidity: Float = 0.30
}
