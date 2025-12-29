.PHONY: test lint format check all clean

# Neovim minimum version
NVIM_MIN_VERSION := 0.10.0

# Test runner
test:
	@echo "Running tests..."
	@nvim --headless -c "PlenaryBustedDirectory lua/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

# Run a single test file
test-file:
	@echo "Running test: $(FILE)"
	@nvim --headless -c "PlenaryBustedFile $(FILE) {minimal_init = 'tests/minimal_init.lua'}"

# Lint with luacheck
lint:
	@echo "Running luacheck..."
	@luacheck lua/ --config .luacheckrc

# Format with stylua
format:
	@echo "Formatting with stylua..."
	@stylua lua/ plugin/ --config-path stylua.toml

# Check format without modifying
format-check:
	@echo "Checking format..."
	@stylua lua/ plugin/ --config-path stylua.toml --check

# Type check with lua-language-server
typecheck:
	@echo "Running type check..."
	@lua-language-server --check lua/

# All checks
check: lint format-check typecheck

# Run all (format, lint, test)
all: format lint test

# Clean generated files
clean:
	@echo "Cleaning..."
	@rm -rf .luacheckcache

# Help
help:
	@echo "Available targets:"
	@echo "  test         - Run all tests with plenary"
	@echo "  test-file    - Run a single test file (FILE=path/to/test_spec.lua)"
	@echo "  lint         - Run luacheck"
	@echo "  format       - Format code with stylua"
	@echo "  format-check - Check code format"
	@echo "  typecheck    - Run lua-language-server type check"
	@echo "  check        - Run all checks (lint, format-check, typecheck)"
	@echo "  all          - Format, lint, and test"
	@echo "  clean        - Remove generated files"
