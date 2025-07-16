# Claude Code SDK for Ruby

Ruby SDK for Claude Code with streaming support and ergonomic MCP integration. See the [Claude Code SDK documentation](https://docs.anthropic.com/en/docs/claude-code/sdk) for more information.

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

# Simple query with streaming
ClaudeCodeSDK.query(prompt: "What is 2 + 2?").each do |message|
  if message.is_a?(ClaudeCodeSDK::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts block.text
      end
    end
  end
end
```

## Features

### 🌊 **Real-time Streaming**
- Messages arrive as they're generated (not after completion)
- Low memory footprint - process one message at a time
- Perfect for interactive applications and long-running operations

### 🔧 **Ergonomic MCP Integration** 
- Simple one-line MCP server configuration
- Support for HTTP, SSE, and stdio MCP servers
- Built-in helpers for common use cases

### 🎯 **Model Selection**
- Support for model aliases (`sonnet`, `haiku`, `opus`)
- Full model name specification
- Easy switching between models

### ⚙️ **Complete Configuration**
- All Claude Code CLI options supported
- Custom system prompts
- Tool permission management
- Working directory control

## Examples

### Basic Usage

```ruby
require 'claude_code_sdk'

# With options
options = ClaudeCodeSDK::ClaudeCodeOptions.new(
  model: "sonnet",
  system_prompt: "You are a helpful assistant",
  max_turns: 1
)

ClaudeCodeSDK.query(
  prompt: "Explain Ruby blocks",
  options: options,
  cli_path: "/path/to/claude"
).each do |message|
  # Process streaming messages
end
```

### MCP Integration

```ruby
# Ultra-convenient MCP usage
ClaudeCodeSDK.quick_mcp_query(
  "Use the about tool to describe yourself",
  server_name: "ninja",
  server_url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/",
  tools: "about"
).each do |message|
  # Process MCP responses
end

# Advanced MCP configuration
mcp_servers = ClaudeCodeSDK.add_mcp_server("my_server", {
  command: "node",
  args: ["my-mcp-server.js"],
  env: { "API_KEY" => "secret" }
})

options = ClaudeCodeSDK::ClaudeCodeOptions.new(
  allowed_tools: ["mcp__my_server__my_tool"],
  mcp_servers: mcp_servers
)
```

### Streaming with Custom Handling

```ruby
# Auto-formatted streaming
ClaudeCodeSDK.stream_query(
  prompt: "Count from 1 to 5",
  options: ClaudeCodeSDK::ClaudeCodeOptions.new(max_turns: 1)
)

# Custom streaming with timestamps
start_time = Time.now
ClaudeCodeSDK.stream_query(
  prompt: "Explain inheritance",
  options: ClaudeCodeSDK::ClaudeCodeOptions.new(max_turns: 1)
) do |message, index|
  timestamp = Time.now - start_time
  puts "[#{format('%.2f', timestamp)}s] #{message}"
end
```

### Rails + Sidekiq Integration

```ruby
# Background job with real-time streaming
class ClaudeStreamingJob
  include Sidekiq::Job
  
  def perform(user_id, query_id, prompt, options = {})
    channel = "claude_stream_#{user_id}_#{query_id}"
    
    ClaudeCodeSDK.query(prompt: prompt, options: options).each do |message|
      # Broadcast to ActionCable
      ActionCable.server.broadcast(channel, {
        type: 'message',
        data: serialize_message(message),
        timestamp: Time.current
      })
    end
  end
end
```

## API Reference

### Core Methods

#### `ClaudeCodeSDK.query(prompt:, options: nil, cli_path: nil, mcp_servers: {})`
Main method for querying Claude with streaming support.

#### `ClaudeCodeSDK.quick_mcp_query(prompt, server_name:, server_url:, tools:, **options)`
Convenient method for quick MCP server usage.

#### `ClaudeCodeSDK.stream_query(prompt:, options: nil, cli_path: nil, mcp_servers: {}, &block)`
Streaming helper with auto-formatting or custom block handling.

#### `ClaudeCodeSDK.add_mcp_server(name, config)`
Helper to create MCP server configurations.

### Configuration Classes

#### `ClaudeCodeOptions`
Main configuration class with all CLI options:
- `model` - Model alias or full name
- `max_turns` - Limit conversation turns
- `system_prompt` - Custom system prompt
- `allowed_tools` - Tools to allow
- `mcp_servers` - MCP server configurations
- `permission_mode` - Permission handling mode
- `cwd` - Working directory

#### MCP Server Configurations
- `McpHttpServerConfig` - HTTP/HTTPS MCP servers
- `McpSSEServerConfig` - Server-Sent Events MCP servers  
- `McpStdioServerConfig` - Stdio MCP servers

### Message Types

#### `SystemMessage`
- `subtype` - Message subtype (e.g., "init")
- `data` - System data (session_id, tools, etc.)

#### `AssistantMessage`
- `content` - Array of content blocks

#### Content Blocks
- `TextBlock` - Text content
- `ToolUseBlock` - Tool usage with input
- `ToolResultBlock` - Tool results

#### `ResultMessage`
- `duration_ms` - Total duration
- `total_cost_usd` - API cost
- `session_id` - Conversation session
- `result` - Final result text

## Error Handling

```ruby
begin
  ClaudeCodeSDK.query(prompt: "Hello").each do |message|
    # Process message
  end
rescue ClaudeCodeSDK::CLINotFoundError
  puts "Please install Claude Code"
rescue ClaudeCodeSDK::ProcessError => e
  puts "Process failed: #{e.exit_code}"
rescue ClaudeCodeSDK::CLIJSONDecodeError => e
  puts "JSON parsing failed: #{e.message}"
end
```

## Examples Directory

- `examples/basic_usage.rb` - Basic SDK usage
- `examples/model_examples.rb` - Model specification examples
- `examples/mcp_examples.rb` - MCP integration examples
- `examples/streaming_examples.rb` - Streaming demonstrations
- `examples/rails_sidekiq_example.rb` - Rails/Sidekiq integration
- `examples/irb_helpers.rb` - IRB convenience functions

## IRB Quick Start

```ruby
# Load helpers
require_relative 'examples/irb_helpers'

# Try these commands:
quick_claude("What is Ruby?")
stream_claude("Explain blocks")
ninja_test("Tell me about yourself")
auto_stream("Count to 5")
```

## License

MIT