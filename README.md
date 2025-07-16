# Claude Code SDK for Ruby

Unofficial Ruby SDK for Claude Code. See the [Claude Code SDK documentation](https://docs.anthropic.com/en/docs/claude-code/sdk) for more information.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'claude_code'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install claude_code
```

**Prerequisites:**
- Ruby 3.0+
- Node.js
- Claude Code: `npm install -g @anthropic-ai/claude-code`

## Quick Start

```ruby
require 'claude_code'

# Simple query
ClaudeCode.query(prompt: "What is 2 + 2?").each do |message|
  puts message
end
```

## Usage

### Authentication

First, set your API key:

```bash
export ANTHROPIC_API_KEY='your-api-key-here'
```

Or for Amazon Bedrock:
```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_ACCESS_KEY_ID='your-access-key'
export AWS_SECRET_ACCESS_KEY='your-secret-key'  
export AWS_REGION='us-west-2'
```

Or for Google Vertex AI:
```bash
export CLAUDE_CODE_USE_VERTEX=1
export GOOGLE_APPLICATION_CREDENTIALS='path/to/service-account.json'
export GOOGLE_CLOUD_PROJECT='your-project-id'
```

### Basic Query

```ruby
require 'claude_code'

# Simple query
ClaudeCode.query(prompt: "Hello Claude").each do |message|
  if message.is_a?(ClaudeCode::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCode::TextBlock)
        puts block.text
      end
    end
  end
end

# With options
options = ClaudeCode::ClaudeCodeOptions.new(
  system_prompt: "You are a helpful assistant",
  max_turns: 1
)

ClaudeCode.query(prompt: "Tell me a joke", options: options).each do |message|
  puts message
end
```

### Conversation Resuming

```ruby
# Continue the most recent conversation
ClaudeCode.continue_conversation("What did we just discuss?").each do |message|
  # Process messages...
end

# Resume a specific conversation by session ID
session_id = "550e8400-e29b-41d4-a716-446655440000"
ClaudeCode.resume_conversation(session_id, "Continue our discussion").each do |message|
  # Process messages...
end

# Continue with options
options = ClaudeCode::ClaudeCodeOptions.new(max_turns: 2)
ClaudeCode.continue_conversation("Add more details", options: options)
```

### Streaming JSON Input

For multi-turn conversations without restarting the CLI, use streaming JSON input:

```ruby
# Create multiple user messages for a conversation
messages = [
  ClaudeCode::JSONLHelpers.create_user_message("Hello! I'm working on a Ruby project."),
  ClaudeCode::JSONLHelpers.create_user_message("Can you help me understand modules?"),
  ClaudeCode::JSONLHelpers.create_user_message("Show me a practical example.")
]

# Process all messages in a single streaming session
ClaudeCode.stream_json_query(messages) do |message|
  case message
  when ClaudeCode::AssistantMessage
    message.content.each do |block|
      puts block.text if block.is_a?(ClaudeCode::TextBlock)
    end
  when ClaudeCode::ResultMessage
    puts "Cost: $#{message.total_cost_usd}"
  end
end

# Manual JSONL format (equivalent to CLI)
custom_messages = [
  {
    'type' => 'user',
    'message' => {
      'role' => 'user',
      'content' => [{'type' => 'text', 'text' => 'Explain this code'}]
    }
  }
]

ClaudeCode.stream_json_query(custom_messages)
```

### Using Tools

```ruby
options = ClaudeCode::ClaudeCodeOptions.new(
  allowed_tools: ["Read", "Write", "Bash"],
  permission_mode: 'acceptEdits'  # auto-accept file edits
)

ClaudeCode.query(
  prompt: "Create a hello.rb file",
  options: options
).each do |message|
  # Process tool use and results
end
```

### Working Directory

```ruby
options = ClaudeCode::ClaudeCodeOptions.new(
  cwd: "/path/to/project"
)
```

## API Reference

### Core Methods

#### `ClaudeCode.query(prompt:, options: nil, cli_path: nil, mcp_servers: {})`

Main function for querying Claude.

**Parameters:**
- `prompt` (String): The prompt to send to Claude
- `options` (ClaudeCodeOptions): Optional configuration
- `cli_path` (String): Optional path to Claude CLI binary
- `mcp_servers` (Hash): Optional MCP server configurations

**Returns:** Enumerator of response messages

#### `ClaudeCode.continue_conversation(prompt = nil, options: nil, cli_path: nil, mcp_servers: {})`

Continue the most recent conversation.

**Parameters:**
- `prompt` (String): Optional new prompt to add
- `options` (ClaudeCodeOptions): Optional configuration
- `cli_path` (String): Optional path to Claude CLI binary
- `mcp_servers` (Hash): Optional MCP server configurations

**Returns:** Enumerator of response messages

#### `ClaudeCode.resume_conversation(session_id, prompt = nil, options: nil, cli_path: nil, mcp_servers: {})`

Resume a specific conversation by session ID.

**Parameters:**
- `session_id` (String): The session ID to resume
- `prompt` (String): Optional new prompt to add
- `options` (ClaudeCodeOptions): Optional configuration
- `cli_path` (String): Optional path to Claude CLI binary
- `mcp_servers` (Hash): Optional MCP server configurations

**Returns:** Enumerator of response messages

#### `ClaudeCode.stream_query(prompt:, options: nil, cli_path: nil, mcp_servers: {}, &block)`

Stream query responses with auto-formatting or custom block handling.

#### `ClaudeCode.stream_json_query(messages, options: nil, cli_path: nil, mcp_servers: {})`

Send multiple messages via streaming JSON input (JSONL format). This allows multiple turns of conversation without re-launching the Claude binary.

**Parameters:**
- `messages` (Array): Array of JSONL message objects
- `options` (ClaudeCodeOptions): Optional configuration (automatically sets input_format: 'stream-json')
- `cli_path` (String): Optional path to Claude CLI binary
- `mcp_servers` (Hash): Optional MCP server configurations

**Returns:** Enumerator of response messages

#### `ClaudeCode.quick_mcp_query(prompt, server_name:, server_url:, tools:, **options)`

Ultra-convenient method for quick MCP server usage.

#### `ClaudeCode.add_mcp_server(name, config)`

Helper to create MCP server configurations.

### JSONL Helpers

#### `ClaudeCode::JSONLHelpers.create_user_message(text)`

Create a user message in the format expected by Claude CLI.

#### `ClaudeCode::JSONLHelpers.create_conversation(*turns)`

Create multiple user messages from text strings.

#### `ClaudeCode::JSONLHelpers.format_messages_as_jsonl(messages)`

Format multiple messages as JSONL string.

### Types

See [lib/claude_code_sdk/types.rb](lib/claude_code_sdk/types.rb) for complete type definitions:
- `ClaudeCodeOptions` - Configuration options
- `AssistantMessage`, `UserMessage`, `SystemMessage`, `ResultMessage` - Message types
- `TextBlock`, `ToolUseBlock`, `ToolResultBlock` - Content blocks

## Error Handling

```ruby
begin
  ClaudeCode.query(prompt: "Hello").each do |message|
    # Process message
  end
rescue ClaudeCode::CLINotFoundError
  puts "Please install Claude Code"
rescue ClaudeCode::ProcessError => e
  puts "Process failed with exit code: #{e.exit_code}"
rescue ClaudeCode::CLIJSONDecodeError => e
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
