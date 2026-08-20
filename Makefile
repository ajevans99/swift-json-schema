# Variables
SUBMODULE_DIR = Tests/JSONSchemaTests/JSON-Schema-Test-Suite
JSON_TEST_SUITE_DIR = Tests/OrderedJSONTests/JSONTestSuite

# Target to initialize and update the submodule
update-submodule:
	@git submodule init
	@git submodule update --remote $(SUBMODULE_DIR)
	@git submodule update --remote $(JSON_TEST_SUITE_DIR)
	@echo "Submodules updated successfully."

format:
	@find Sources Tests Benchmarks \
		\( -path 'Tests/JSONSchemaTests/JSON-Schema-Test-Suite' \
			-o -path 'Tests/OrderedJSONTests/JSONTestSuite' \
			-o -path 'Benchmarks/.build' \) -prune \
		-o -name '*.swift' \
		-print0 | xargs -0 swift format --in-place --parallel
	@find Sources Tests Benchmarks \
		\( -path 'Tests/JSONSchemaTests/JSON-Schema-Test-Suite' \
			-o -path 'Tests/OrderedJSONTests/JSONTestSuite' \
			-o -path 'Benchmarks/.build' \) -prune \
		-o -name '*.swift' \
		-print0 | xargs -0 swift format lint --strict --parallel
	@echo "Swift code formatted successfully."

.PHONY: clean-submodule format
