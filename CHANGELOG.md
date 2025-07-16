# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.18] - 2025-01-16

### Fixed
- Fixed command line length limit issue by switching from command line arguments to stdin for prompt input
- This resolves errors when using long prompts that exceed system ARG_MAX limits

### Added
- Real-time streaming support with lazy enumerators
- Ergonomic MCP (Model Context Protocol) integration
- Rails + Sidekiq + ActionCable streaming integration examples
- Advanced error handling with user-friendly installation instructions
- IRB helpers for quick testing and development
- Comprehensive documentation and examples
- Model selection with aliases (sonnet, haiku, opus)
- Advanced CLI subprocess management with proper cleanup
- Buffer overflow protection for large JSON messages

### Enhanced
- Better gem structure following Ruby best practices
- Improved test infrastructure with coverage reporting
- Development tooling with Rake, RuboCop, and YARD
- Professional documentation and README

## [0.0.1] - 2025-01-16

### Added
- Initial Ruby SDK implementation for Claude Code
- Core streaming functionality
- MCP server integration
- Basic error handling
- Examples and documentation

[Unreleased]: https://github.com/anthropics/claude-code-sdk-python/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/anthropics/claude-code-sdk-python/releases/tag/ruby-v0.0.1