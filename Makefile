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
		-name '*.swift' \
		-not -path '*/JSON-Schema-Test-Suite/*' \
		-not -path '*/JSONTestSuite/*' \
		-not -path 'Benchmarks/.build/*' \
		-print0 | xargs -0 swift format --in-place --parallel
	@find Sources Tests Benchmarks \
		-name '*.swift' \
		-not -path '*/JSON-Schema-Test-Suite/*' \
		-not -path '*/JSONTestSuite/*' \
		-not -path 'Benchmarks/.build/*' \
		-print0 | xargs -0 swift format lint --strict --parallel
	@echo "Swift code formatted successfully."

.PHONY: clean-submodule format
