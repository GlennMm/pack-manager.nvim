# Makefile for Pack-Manager.nvim development

.PHONY: help format lint check test clean install

# Default target
help:
	@echo "Available commands:"
	@echo "  format    - Format Lua code with StyLua"
	@echo "  lint      - Lint Lua code with Luacheck"
	@echo "  check     - Run both format check and lint"
	@echo "  test      - Run tests (if implemented)"
	@echo "  clean     - Clean temporary files"
	@echo "  install   - Install development dependencies"

# Format code with StyLua
format:
	@echo "Formatting Lua code with StyLua..."
	stylua --config-path stylua.toml lua/ plugin/
	@echo "✓ Formatting complete"

# Check formatting without applying changes
format-check:
	@echo "Checking Lua code formatting..."
	stylua --config-path stylua.toml --check lua/ plugin/

# Lint code with Luacheck
lint:
	@echo "Linting Lua code with Luacheck..."
	luacheck .
	@echo "✓ Linting complete"

# Run both format check and lint
check: format-check lint
	@echo "✓ All checks passed"

# Run tests (placeholder for future implementation)
test:
	@echo "Running tests..."
	@echo "⚠ Tests not implemented yet"
	# busted tests/

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	find . -name "*.tmp" -delete
	find . -name "*.log" -delete
	find . -name ".DS_Store" -delete
	@echo "✓ Cleanup complete"

# Install development dependencies
install:
	@echo "Installing development dependencies..."
	@echo "Please install the following tools manually:"
	@echo "  - StyLua: https://github.com/JohnnyMorganz/StyLua"
	@echo "  - Luacheck: luarocks install luacheck"
	@echo "  - Busted (optional): luarocks install busted"

# Development workflow - format and check
dev: format lint
	@echo "✓ Development workflow complete"

# CI workflow - check without modifying files
ci: format-check lint
	@echo "✓ CI checks passed"
