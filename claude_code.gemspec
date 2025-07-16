# frozen_string_literal: true

require_relative 'lib/claude_code/version'

Gem::Specification.new do |spec|
  spec.name = 'claude_code'
  spec.version = ClaudeCode::VERSION
  spec.authors = ['Your Name']
  spec.email = ['your.email@example.com']

  spec.summary = 'Ruby SDK for Claude Code with streaming support and ergonomic MCP integration'
  spec.description = 'Ruby SDK for Claude Code with streaming support and MCP integration. See the Claude Code SDK documentation for more information.'
  spec.homepage = 'https://github.com/schappim/claude-code-sdk-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/schappim/claude-code-sdk-ruby'
  spec.metadata['documentation_uri'] = 'https://docs.anthropic.com/en/docs/claude-code/sdk'
  spec.metadata['changelog_uri'] = 'https://github.com/schappim/claude-code-sdk-ruby/blob/main/CHANGELOG.md'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?('bin/', 'test/', 'spec/', 'features/', '.git', '.github', 'appveyor', 'Gemfile')
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'json', '~> 2.0'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.add_development_dependency 'rubocop-performance', '~> 1.0'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'yard', '~> 0.9'
end