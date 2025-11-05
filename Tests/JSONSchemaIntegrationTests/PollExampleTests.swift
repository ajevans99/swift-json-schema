import JSONSchema
import JSONSchemaBuilder
import SnapshotTesting
import Testing

@Schemable
@SchemaOptions(
  .title("Poll"),
  .description("A schema for representing a poll with options and metadata.")
)
struct Poll {
  @SchemaOptions(.description("Unique identifier for the poll"))
  @NumberOptions(.minimum(1))
  let id: Int

  @SchemaOptions(.description("The title of the poll"))
  @StringOptions(.minLength(1), .maxLength(200))
  let title: String

  @SchemaOptions(.description("Optional description of the poll"))
  @StringOptions(.maxLength(500))
  let description: String?

  @StringOptions(.format("date-time"))
  let createdAt: String

  @SchemaOptions(.description("Optional expiration timestamp for the poll"))
  @StringOptions(.format("date-time"))
  let expiresAt: String?

  @SchemaOptions(.description("Whether the poll is currently active"), .default(true))
  var isActive: Bool

  @SchemaOptions(.description("List of options available in the poll"))
  @ArrayOptions(.minItems(2), .uniqueItems(true))
  let options: [Option]

  @SchemaOptions(.description("Category of the poll, limited to specific types"))
  let category: Category

  let settings: Settings?

  init(
    id: Int,
    title: String,
    description: String?,
    createdAt: String,
    expiresAt: String?,
    isActive: Bool = true,
    options: [Option],
    category: Category,
    settings: Settings?
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.createdAt = createdAt
    self.expiresAt = expiresAt
    self.isActive = isActive
    self.options = options
    self.category = category
    self.settings = settings
  }

  @Schemable
  @ObjectOptions(.additionalProperties { false })
  struct Option {
    @SchemaOptions(.description("Unique identifier for the poll"))
    @NumberOptions(.minimum(1))
    let id: Int

    @SchemaOptions(.description("Option text"))
    @StringOptions(.minLength(1), .maxLength(100))
    let text: String

    @SchemaOptions(.description("Number of votes received"), .default(0))
    @NumberOptions(.minimum(0))
    var voteCount: Int

    init(id: Int, text: String, voteCount: Int = 0) {
      self.id = id
      self.text = text
      self.voteCount = voteCount
    }
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
    @SchemaOptions(.default(true))
    var allowMultipleVotes: Bool

    @SchemaOptions(.default(false))
    var requireAuthentication: Bool

    init(allowMultipleVotes: Bool = true, requireAuthentication: Bool = false) {
      self.allowMultipleVotes = allowMultipleVotes
      self.requireAuthentication = requireAuthentication
    }
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
      case g = "General Audience", pg = "Parental Guidance Suggested", pg13 =
        "Parental Guidance Suggested 13+", r = "Restricted"
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
  /// Toggle to true to re-record snapshots, then run.
  /// Don't forget to set it back to false.
  private static let shouldRecord: SnapshotTestingConfiguration.Record = false

  struct TestInstance {
    let id: String
    let data: String
    let description: String

    let shouldParse: Bool
    let isValid: Bool
  }

  @Test(.snapshots(record: shouldRecord))
  func defintion() {
    assertSnapshot(of: Poll.schema.definition(), as: .json)
  }

  static let instances = [
    TestInstance(
      id: "1",
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
          "category": {
            "technology": {
              "_0": {
                "subTopic": "software",
                "hasDemo": true
              }
            }
          },
          "settings": {
            "allowMultipleVotes": false,
            "requireAuthentication": true
          }
        }
        """,
      description: "Technology category with settings",
      shouldParse: true,
      isValid: true
    ),
    TestInstance(
      id: "2",
      data: """
        {
          "id": 2,
          "title": "Favorite Movie Genre?",
          "options": [
            {"id": 1, "text": "Action", "voteCount": 5},
            {"id": 2, "text": "Drama", "voteCount": 8}
          ],
          "createdAt": "2024-10-26T08:30:00Z",
          "isActive": false,
          "category": {
            "entertainment": {
              "_0": {
                "genre": "movies",
                "ageRating": "Parental Guidance Suggested 13+"
              }
            }
          }
        }
        """,
      description: "Entertainment category",
      shouldParse: true,
      isValid: true
    ),
    TestInstance(
      id: "3",
      data: """
        {
          "id": 3,
          "title": "Favorite Sport?",
          "options": [
            {"id": 1, "text": "Soccer", "voteCount": 25},
            {"id": 2, "text": "Basketball", "voteCount": 30}
          ],
          "createdAt": "2024-10-25T15:00:00Z",
          "isActive": false,
          "category": "sports"
        }
        """,
      description: "Sports category",
      shouldParse: true,
      isValid: true
    ),
    TestInstance(
      id: "4",
      data: """
        {
          "id": 4,
          "options": [
            {"id": 1, "text": "Option A", "voteCount": 2},
            {"id": 2, "text": "Option B", "voteCount": 4}
          ],
          "createdAt": "2024-10-25T18:00:00Z",
          "isActive": true,
          "category": {
            "education": {
              "_0": {
                "subject": "science",
                "level": "second"
              }
            }
          }
        }
        """,
      description: "Mising required title",
      shouldParse: false,
      isValid: false
    ),
    TestInstance(
      id: "5",
      data: """
        {
          "id": 5,
          "title": "Favorite Food?",
          "options": [
            {"id": 1, "text": "Pizza", "voteCount": 5},
            {"id": 2, "text": "Burger", "voteCount": 3}
          ],
          "createdAt": "2024-10-25T12:00:00Z",
          "isActive": false,
          "category": {
            "food": {
              "_0": {
                "customDescription": "What's your favorite?"
              }
            },
          }
        }
        """,
      description: "Invalid category type",
      shouldParse: false,
      isValid: false
    ),
    TestInstance(
      id: "6",
      data: """
        {
          "id": 6,
          "title": "Invalid Poll",
          "options": [
            {"id": -1, "text": "Option A", "voteCount": 5}
          ],
          "createdAt": "2024-10-25T12:00:00Z",
          "isActive": true,
          "category": "other"
        }
        """,
      description: "Invalid option ID (negative) and insufficient options count",
      shouldParse: true,
      isValid: false
    ),
    TestInstance(
      id: "7",
      data: """
        {
          "id": 7,
          "title": "",
          "options": [
            {"id": 1, "text": "", "voteCount": -5},
            {"id": 2, "text": "Valid Option", "voteCount": 0}
          ],
          "createdAt": "invalid-date",
          "isActive": true,
          "category": "other"
        }
        """,
      description:
        "Multiple validation errors: empty title, empty option text, negative vote count, invalid date format",
      shouldParse: true,
      isValid: false
    ),
  ]

  @Test(.snapshots(record: shouldRecord), arguments: instances)
  func parse(instance: TestInstance) throws {
    let pollResult = try Poll.schema.parse(instance: instance.data)
    assertSnapshot(of: pollResult, as: .dump, named: instance.id)
    #expect(instance.shouldParse ? pollResult.value != nil : pollResult.errors?.isEmpty == false)
  }

  @Test(arguments: instances)
  func validate(instance: TestInstance) throws {
    let schema = Poll.schema.definition()
    let validationResult = try schema.validate(instance: instance.data)
    // TODO: The order of errors and annotations arrays are not deterministic so standard JSON comparison does not work here, need a custom `Snapshotting` strategy I think
    // assertSnapshot(of: validationResult.sorted(), as: .json)
    #expect(instance.isValid == validationResult.isValid)
  }

  @Test(arguments: instances)
  func parseAndValidate(instance: TestInstance) throws {
    if instance.isValid && instance.shouldParse {
      #expect(throws: Never.self) {
        _ = try Poll.schema.parseAndValidate(instance: instance.data)
      }
    } else {
      #expect(throws: ParseAndValidateIssue.self) {
        _ = try Poll.schema.parseAndValidate(instance: instance.data)
      }
    }
  }
}
