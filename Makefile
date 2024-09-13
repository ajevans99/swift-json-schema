# Variables
SUBMODULE_DIR = Tests/JSONSchema2Tests/JSON-Schema-Test-Suite

# Target to initialize and update the submodule
update-submodule:
	@git submodule init
	@git submodule update --remote $(SUBMODULE_DIR)
	@echo "Submodule $(SUBMODULE_DIR) updated successfully."

format:
	@swift-format format --in-place --parallel --recursive Sources/ Tests/
	@swift-format lint --strict --parallel --recursive Sources/ Tests/
	@echo "Swift code formatted successfully."

.PHONY: clean-submodule format
