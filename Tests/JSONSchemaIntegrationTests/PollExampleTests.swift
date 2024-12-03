import JSONSchema
import JSONSchemaBuilder
import SnapshotTesting
import Testing

@Schemable
@SchemaOptions(title: "Poll", description: "A schema for representing a poll with options and metadata.")
struct Poll {
  @SchemaOptions(description: "Unique identifier for the poll")
  @NumberOptions(minimum: 1)
  let id: Int

  @SchemaOptions(description: "The title of the poll")
  @StringOptions(minLength: 1, maxLength: 200)
  let title: String

  @SchemaOptions(description: "Optional description of the poll")
  @StringOptions(maxLength: 500)
  let description: String?

  @StringOptions(format: "date-time")
  let createdAt: String

  @SchemaOptions(description: "Optional expiration timestamp for the poll")
  @StringOptions(format: "date-time")
  let expiresAt: String?

  @SchemaOptions(description: "Whether the poll is currently active")
  var isActive: Bool = true

  @SchemaOptions(description: "List of options available in the poll")
  @ArrayOptions(minItems: 2, uniqueItems: true)
  let options: [Option]

  @SchemaOptions(description: "Visibility of the poll")
  let visibility: Visibility

  @SchemaOptions(description: "Category of the poll, limited to specific types")
  let category: Category

  let settings: Settings?

  @Schemable
  @ObjectOptions() // TODO: Additional properties to false
  struct Option {
    @SchemaOptions(description: "Unique identifier for the poll")
    @NumberOptions(minimum: 1)
    let id: Int

    @SchemaOptions(description: "Option text")
    @StringOptions(minLength: 1, maxLength: 100)
    let text: String

    @SchemaOptions(description: "Number of votes received")
    @NumberOptions(minimum: 0)
    var voteCount: Int = 0
  }

  @Schemable
  enum Visibility {
    case `public`
    case `private`
  }

  @Schemable
  enum Category {
    case technology(Technology)
    case entertainment(Entertainment)
    case education(Education)
    case sports
    case other
  }

  @Schemable
  struct Settings {
    var allowMulipleVotes: Bool = true
    var requireAuthentication: Bool = false
  }
}

extension Poll.Category {
  @Schemable
  struct Technology {
    let subTopic: String
    let hasDemo: Bool
  }

  @Schemable
  struct Entertainment {
    @Schemable
    enum Genre {
      case movies, music, games, television
    }

    @Schemable
    enum AgeRating: String {
      case g = "General Audience", pg = "Parental Guidance Suggested", pg13 = "Parental Guidance Suggested 13+", r = "Restricted"
    }

    let genre: Genre
    let ageRating: AgeRating
  }

  @Schemable
  struct Education {
    @Schemable
    enum Subject {
      case math, science, history, english, art, music, foreignLanguage
    }

    let subject: Subject
    let level: String
  }
}

struct PollExampleTests {
  struct TestInstance {
    let data: String
    let description: String

    let shouldParse: Bool
  }

  @Test func defintion() {
    assertSnapshot(of: Poll.schema.definition(), as: .json)
  }

  static let instances = [
    TestInstance(
      data: """
        {
          "id": 1,
          "title": "Favorite Programming Language?",
          "description": "Vote for your favorite language.",
          "options": [
            {"id": 1, "text": "Swift", "voteCount": 10},
            {"id": 2, "text": "Python", "voteCount": 20}
          ],
          "createdAt": "2024-10-25T12:00:00Z",
          "expiresAt": "2024-12-31T23:59:59Z",
          "isActive": true,
          "visibility": "public",
          "category": {
            "type": "technology",
            "_0": {
              "subTopic": "software",
              "hasDemo": true
            }
          },
          "settings": {
            "allowMultipleVotes": false,
            "requireAuthentication": true
          }
        }
        """,
      description: "Technology category with settings",
      shouldParse: true
    ),
    TestInstance(
      data: """
        {
          "id": 2,
          "title": "Favorite Movie Genre?",
          "options": [
            {"id": 1, "text": "Action", "voteCount": 5},
            {"id": 2, "text": "Drama", "voteCount": 8}
          ],
          "created_at": "2024-10-26T08:30:00Z",
          "category": {
            "type": "entertainment",
            "_0": {
              "genre": "movies",
              "ageRating": "PG-13"
            }
          }
        }
        """,
      description: "Entertainment category",
      shouldParse: true
    ),
    TestInstance(
      data: """
        {
          "id": 3,
          "title": "Favorite Sport?",
          "options": [
            {"id": 1, "text": "Soccer", "voteCount": 25},
            {"id": 2, "text": "Basketball", "voteCount": 30}
          ],
          "created_at": "2024-10-25T15:00:00Z",
          "category": {
            "type": "sports",
            "sportType": "soccer",
            "isTeamSport": true
          }
        }
        """,
      description: "Sports category",
      shouldParse: true
    ),
    TestInstance(
      data: """
        {
          "id": 4,
          "options": [
            {"id": 1, "text": "Option A", "voteCount": 2},
            {"id": 2, "text": "Option B", "voteCount": 4}
          ],
          "created_at": "2024-10-25T18:00:00Z",
          "category": {
            "type": "education",
            "_0": {
              "subject": "science"
            }
          }
        }
        """,
      description: "Mising required title",
      shouldParse: false
    ),
    TestInstance(
      data: """
        {
          "id": 7,
          "title": "Favorite Food?",
          "options": [
            {"id": 1, "text": "Pizza", "voteCount": 5},
            {"id": 2, "text": "Burger", "voteCount": 3}
          ],
          "created_at": "2024-10-25T12:00:00Z",
          "category": {
            "type": "food",
            "customDescription": "What's your favorite?"
          }
        }
        """,
      description: "Invalid category type",
      shouldParse: true
    ),
    TestInstance(
      data: """
        {
          "id": 8,
          "title": "Invalid Poll",
          "options": [
            {"id": -1, "text": "Option A", "voteCount": 5}
          ],
          "createdAt": "2024-10-25T12:00:00Z",
          "category": "other",
          "visibility": "public"
        }
        """,
      description: "Invalid option ID (negative) and insufficient options count",
      shouldParse: true
    ),
    TestInstance(
      data: """
        {
          "id": 9,
          "title": "",
          "options": [
            {"id": 1, "text": "", "voteCount": -5},
            {"id": 2, "text": "Valid Option", "voteCount": 0}
          ],
          "createdAt": "invalid-date",
          "category": "other",
          "visibility": "public"
        }
        """,
      description: "Multiple validation errors: empty title, empty option text, negative vote count, invalid date format",
      shouldParse: true
    ),
  ]

  @Test(arguments: instances)
  func parse(instance: TestInstance) throws {
    let pollResult = try Poll.schema.parse(instance: instance.data)
    assertSnapshot(of: pollResult, as: .dump)
  }

  @Test(arguments: instances)
  func validate(instance: TestInstance) throws {
    let schema = Poll.schema.definition()
    let validationResult = try schema.validate(instance: instance.data)
    assertSnapshot(of: validationResult, as: .json)
  }
}
