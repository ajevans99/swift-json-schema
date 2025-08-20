import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
enum Emotion {
  case happy
  case sad
  case excited
  case calm
  case anxious
}

@Schemable
enum Priority {
  case low
  case medium
  case high
  case critical
}

@Schemable
struct Task {
  /// Unique identifier for the task
  @SchemaOptions(.description("Unique identifier for the task"))
  let id: String

  /// Title of the task
  @StringOptions(.minLength(1), .maxLength(100))
  let title: String

  /// Detailed description of the task
  @StringOptions(.maxLength(500))
  let description: String?

  /// Priority level of the task
  let priority: Priority

  /// Whether the task is completed
  let isCompleted: Bool

  /// Tags associated with the task
  @ArrayOptions(.minItems(0), .maxItems(10))
  let tags: [String]

  /// Emotional state while working on the task
  let emotionalState: Emotion?

  /// When the task was created
  @StringOptions(.format("date-time"))
  let createdAt: String

  /// When the task is due
  @StringOptions(.format("date-time"))
  let dueDate: String?
}

@Schemable
struct Project {
  /// Unique identifier for the project
  let id: String

  /// Name of the project
  @StringOptions(.minLength(1), .maxLength(200))
  let name: String

  /// Project description
  @StringOptions(.maxLength(1000))
  let description: String?

  /// Tasks organized by priority
  let tasksByPriority: [Priority: [Task]]

  /// Tasks organized by emotional state
  let tasksByEmotion: [Emotion: [Task]]

  /// General project metadata
  let metadata: [String: String]

  /// Project statistics
  let stats: [String: Int]

  /// Project team members
  @ArrayOptions(.minItems(1))
  let teamMembers: [String]

  /// Project milestones
  @ArrayOptions(.minItems(0))
  let milestones: [String]

  /// When the project was created
  @StringOptions(.format("date-time"))
  let createdAt: String

  /// Project status
  let status: ProjectStatus
}

@Schemable
enum ProjectStatus {
  case planning
  case active
  case onHold
  case completed
  case cancelled
}

// MARK: - Integration Tests

struct DictionaryArrayIntegrationTests {
  @Test
  func testValidProjectWithComplexDictionaries() throws {
    let json = """
      {
        "id": "proj-001",
        "name": "AI-Powered Task Manager",
        "description": "A sophisticated task management system with emotional intelligence",
        "tasksByPriority": {
          "high": [
            {
              "id": "task-001",
              "title": "Design Core Architecture",
              "description": "Create the foundational system design",
              "priority": "high",
              "isCompleted": false,
              "tags": ["architecture", "design"],
              "emotionalState": "excited",
              "createdAt": "2024-01-15T09:00:00Z",
              "dueDate": "2024-01-22T17:00:00Z"
            }
          ],
          "medium": [
            {
              "id": "task-002",
              "title": "Write Documentation",
              "description": "Document the API endpoints",
              "priority": "medium",
              "isCompleted": true,
              "tags": ["documentation", "api"],
              "emotionalState": "calm",
              "createdAt": "2024-01-10T14:00:00Z",
              "dueDate": "2024-01-17T17:00:00Z"
            }
          ]
        },
        "tasksByEmotion": {
          "excited": [
            {
              "id": "task-001",
              "title": "Design Core Architecture",
              "description": "Create the foundational system design",
              "priority": "high",
              "isCompleted": false,
              "tags": ["architecture", "design"],
              "emotionalState": "excited",
              "createdAt": "2024-01-15T09:00:00Z",
              "dueDate": "2024-01-22T17:00:00Z"
            }
          ],
          "calm": [
            {
              "id": "task-002",
              "title": "Write Documentation",
              "description": "Document the API endpoints",
              "priority": "medium",
              "isCompleted": true,
              "tags": ["documentation", "api"],
              "emotionalState": "calm",
              "createdAt": "2024-01-10T14:00:00Z",
              "dueDate": "2024-01-17T17:00:00Z"
            }
          ]
        },
        "metadata": {
          "department": "Engineering",
          "budget": "50000",
          "client": "Internal"
        },
        "stats": {
          "totalTasks": 2,
          "completedTasks": 1,
          "teamSize": 3
        },
        "teamMembers": ["alice", "bob", "charlie"],
        "milestones": ["Design Complete", "MVP Ready", "Production Launch"],
        "createdAt": "2024-01-01T00:00:00Z",
        "status": "active"
      }
      """

    let result = try Project.schema.parse(instance: json)

    // Verify parsing succeeded
    #expect(result.value != nil, "Expected successful parsing")
    #expect(result.errors == nil, "Expected no validation errors")

    guard let project = result.value else {
      throw TestError("Failed to parse project")
    }

    // Verify basic properties
    #expect(project.id == "proj-001")
    #expect(project.name == "AI-Powered Task Manager")
    #expect(project.status == .active)

    // Verify custom key schema dictionaries
    #expect(project.tasksByPriority.count == 2)
    #expect(project.tasksByPriority[.high]?.count == 1)
    #expect(project.tasksByPriority[.medium]?.count == 1)
    #expect(project.tasksByPriority[.low] == nil)

    #expect(project.tasksByEmotion.count == 2)
    #expect(project.tasksByEmotion[.excited]?.count == 1)
    #expect(project.tasksByEmotion[.calm]?.count == 1)
    #expect(project.tasksByEmotion[.sad] == nil)

    // Verify string key dictionaries
    #expect(project.metadata["department"] == "Engineering")
    #expect(project.metadata["budget"] == "50000")
    #expect(project.stats["totalTasks"] == 2)
    #expect(project.stats["completedTasks"] == 1)

    // Verify arrays
    #expect(project.teamMembers.count == 3)
    #expect(project.teamMembers.contains("alice"))
    #expect(project.milestones.count == 3)
    #expect(project.milestones.contains("Design Complete"))

    // Verify nested task properties
    let highPriorityTask = project.tasksByPriority[.high]?.first
    #expect(highPriorityTask?.priority == .high)
    #expect(highPriorityTask?.emotionalState == .excited)
    #expect(highPriorityTask?.tags.contains("architecture") == true)
  }

  @Test
  func testParsingVsValidationWithInvalidKeys() throws {
    let json = """
      {
        "id": "proj-002",
        "name": "Invalid Project",
        "description": "This project has invalid keys",
        "tasksByPriority": {
          "invalid_priority": [
            {
              "id": "task-003",
              "title": "Invalid Task",
              "description": "This task has invalid priority",
              "priority": "invalid_priority",
              "isCompleted": false,
              "tags": ["invalid"],
              "emotionalState": "invalid_emotion",
              "createdAt": "2024-01-15T09:00:00Z"
            }
          ]
        },
        "tasksByEmotion": {
          "invalid_emotion": []
        },
        "metadata": {},
        "stats": {},
        "teamMembers": ["alice"],
        "milestones": [],
        "createdAt": "2024-01-01T00:00:00Z",
        "status": "planning"
      }
      """

    // Test parsing (lenient) - should succeed even with invalid keys
    let parseResult = try Project.schema.parse(instance: json)
    #expect(parseResult.value != nil, "Parsing should succeed (lenient)")
    #expect(parseResult.errors == nil, "Parsing should not produce errors for invalid keys")

    // Verify that the data is parsed as expected
    guard let project = parseResult.value else {
      throw TestError("Failed to parse project")
    }

    // The invalid keys are silently dropped during parsing (current behavior)
    #expect(project.tasksByPriority.count == 0, "Invalid keys are dropped during parsing")
    #expect(project.tasksByEmotion.count == 0, "Invalid keys are dropped during parsing")

    // Test validation (strict) - should fail with invalid keys
    let schema = Project.schema.definition()
    let validationResult = try schema.validate(instance: json)
    #expect(validationResult.isValid == false, "Validation should fail with invalid keys")
    #expect(validationResult.errors?.isEmpty == false, "Validation should produce errors")

    // Check that validation produced errors
    if let errors = validationResult.errors {
      #expect(errors.count == 1, "Should have validation errors for invalid keys")
      #expect(errors[0].keyword == "properties", "Validation errors should be of type 'properties'")
    }
  }

  @Test
  func testParsingVsValidationWithInvalidTypes() throws {
    let json = """
      {
        "id": "proj-003",
        "name": "Invalid Values Project",
        "description": "This project has invalid types",
        "tasksByPriority": {
          "high": [
            {
              "id": "task-004",
              "title": "Invalid Task",
              "description": "This task has invalid types",
              "priority": "high",
              "isCompleted": "not_a_boolean",
              "tags": "not_an_array",
              "emotionalState": "high",
              "createdAt": "2024-01-15T09:00:00Z"
            }
          ]
        },
        "tasksByEmotion": {
          "happy": []
        },
        "metadata": {},
        "stats": {
          "totalTasks": "not_a_number"
        },
        "teamMembers": "not_an_array",
        "milestones": [],
        "createdAt": "2024-01-01T00:00:00Z",
        "status": "invalid_status"
      }
      """

    // Test parsing (lenient) - should fail with fundamental type mismatches
    let parseResult = try Project.schema.parse(instance: json)
    #expect(parseResult.value == nil, "Parsing should fail with fundamental type mismatches")
    #expect(parseResult.errors != nil, "Parsing should produce errors for type mismatches")

    // Verify we get type-related parse errors
    if let errors = parseResult.errors {
      #expect(errors.count > 0, "Expected parsing errors")

      // Check for type mismatch errors
      let hasTypeMismatchErrors = errors.contains { error in
        switch error {
        case .typeMismatch: return true
        default: return false
        }
      }
      #expect(hasTypeMismatchErrors, "Should have type mismatch errors")
    }

    // Test validation (strict) - should also fail
    let schema = Project.schema.definition()
    let validationResult = try schema.validate(instance: json)
    #expect(validationResult.isValid == false, "Validation should fail with invalid types")
    #expect(validationResult.errors?.isEmpty == false, "Validation should produce errors")
  }

  @Test
  func testEmptyProjectWithMinimalData() throws {
    let json = """
      {
        "id": "proj-004",
        "name": "Minimal Project",
        "tasksByPriority": {},
        "tasksByEmotion": {},
        "metadata": {},
        "stats": {},
        "teamMembers": ["solo_dev"],
        "milestones": [],
        "createdAt": "2024-01-01T00:00:00Z",
        "status": "planning"
      }
      """

    // Test parsing (lenient) - should succeed with minimal valid data
    let parseResult = try Project.schema.parse(instance: json)
    #expect(parseResult.value != nil, "Parsing should succeed with minimal data")
    #expect(parseResult.errors == nil, "Parsing should not produce errors")

    guard let project = parseResult.value else {
      throw TestError("Failed to parse project")
    }

    // Verify basic properties
    #expect(project.id == "proj-004")
    #expect(project.name == "Minimal Project")
    #expect(project.status == .planning)
    #expect(project.description == nil, "Optional description should be nil when omitted")

    // Verify empty dictionaries are handled correctly
    #expect(project.tasksByPriority.isEmpty)
    #expect(project.tasksByEmotion.isEmpty)
    #expect(project.metadata.isEmpty)
    #expect(project.stats.isEmpty)

    // Verify arrays
    #expect(project.teamMembers.count == 1)
    #expect(project.teamMembers.contains("solo_dev"))
    #expect(project.milestones.count == 0)

    // Test validation (strict) - should also pass for valid minimal data
    let schema = Project.schema.definition()
    let validationResult = try schema.validate(instance: json)
    #expect(validationResult.isValid == true, "Validation should pass for minimal valid data")
    #expect((validationResult.errors?.isEmpty ?? true) == true, "Should have no validation errors")
  }
}

// MARK: - Test Utilities

struct TestError: Error, CustomStringConvertible {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var description: String {
    message
  }
}
