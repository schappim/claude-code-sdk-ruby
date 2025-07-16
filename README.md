# Claude Code SDK for Ruby

Unofficial Ruby SDK for Claude Code. See the [Claude Code SDK documentation](https://docs.anthropic.com/en/docs/claude-code/sdk) for more information.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'claude_code_sdk'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install claude_code_sdk
```

**Prerequisites:**
- Ruby 3.0+
- Node.js
- Claude Code: `npm install -g @anthropic-ai/claude-code`

## Quick Start

```ruby
require 'claude_code_sdk'

# Simple query
ClaudeCodeSDK.query(prompt: "What is 2 + 2?").each do |message|
  puts message
end
```

## Usage

### Basic Query

```ruby
require 'claude_code_sdk'

# Simple query
ClaudeCodeSDK.query(prompt: "Hello Claude").each do |message|
  if message.is_a?(ClaudeCodeSDK::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts block.text
      end
    end
  end
end

# With options
options = ClaudeCodeSDK::ClaudeCodeOptions.new(
  system_prompt: "You are a helpful assistant",
  max_turns: 1
)

ClaudeCodeSDK.query(prompt: "Tell me a joke", options: options).each do |message|
  puts message
end
```

### Using Tools

```ruby
options = ClaudeCodeSDK::ClaudeCodeOptions.new(
  allowed_tools: ["Read", "Write", "Bash"],
  permission_mode: 'acceptEdits'  # auto-accept file edits
)

ClaudeCodeSDK.query(
  prompt: "Create a hello.rb file",
  options: options
).each do |message|
  # Process tool use and results
end
```

### Working Directory

```ruby
options = ClaudeCodeSDK::ClaudeCodeOptions.new(
  cwd: "/path/to/project"
)
```

## API Reference

### `ClaudeCodeSDK.query(prompt:, options: nil)`

Main function for querying Claude.

**Parameters:**
- `prompt` (String): The prompt to send to Claude
- `options` (ClaudeCodeOptions): Optional configuration

**Returns:** Enumerator of response messages

### Types

See [lib/claude_code_sdk/types.rb](lib/claude_code_sdk/types.rb) for complete type definitions:
- `ClaudeCodeOptions` - Configuration options
- `AssistantMessage`, `UserMessage`, `SystemMessage`, `ResultMessage` - Message types
- `TextBlock`, `ToolUseBlock`, `ToolResultBlock` - Content blocks

## Error Handling

```ruby
begin
  ClaudeCodeSDK.query(prompt: "Hello").each do |message|
    # Process message
  end
rescue ClaudeCodeSDK::CLINotFoundError
  puts "Please install Claude Code"
rescue ClaudeCodeSDK::ProcessError => e
  puts "Process failed with exit code: #{e.exit_code}"
rescue ClaudeCodeSDK::CLIJSONDecodeError => e
  puts "Failed to parse response: #{e}"
end
```

See [lib/claude_code_sdk/errors.rb](lib/claude_code_sdk/errors.rb) for all error types.

## Available Tools

See the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code/settings#tools-available-to-claude) for a complete list of available tools.

## Examples

See [examples/quick_start.rb](examples/quick_start.rb) for a complete working example.

## License

MIT
