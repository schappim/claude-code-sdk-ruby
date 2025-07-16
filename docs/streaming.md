# Streaming Support

The Ruby Claude Code SDK provides **real-time streaming** of messages as they arrive from the Claude CLI, enabling responsive user experiences and efficient processing of long-running operations.

## Overview

All queries return lazy enumerators that stream messages in real-time, providing immediate feedback and lower memory usage compared to collecting all messages before processing.

## Streaming Methods

### 1. Default Streaming (query method)

```ruby
# All queries stream by default
ClaudeCodeSDK.query(
  prompt: "Explain Ruby blocks",
  options: ClaudeCodeOptions.new(max_turns: 1)
).each do |message|
  case message
  when ClaudeCodeSDK::SystemMessage
    puts "🔧 System: #{message.subtype}"
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts "💬 #{block.text}"
      end
    end
  when ClaudeCodeSDK::ResultMessage
    puts "✅ Cost: $#{message.total_cost_usd}"
  end
end
```

### 1.5. Streaming JSON Input (Multi-turn Conversations)

For multiple conversation turns without restarting the CLI:

```ruby
# Create multiple user messages
messages = [
  ClaudeCodeSDK::JSONLHelpers.create_user_message("Hello! I need help with Ruby."),
  ClaudeCodeSDK::JSONLHelpers.create_user_message("Can you explain how blocks work?"),
  ClaudeCodeSDK::JSONLHelpers.create_user_message("Show me a practical example.")
]

# Process all messages in a single streaming session
ClaudeCodeSDK.stream_json_query(messages) do |message|
  case message
  when ClaudeCodeSDK::SystemMessage
    puts "🔧 System: #{message.subtype}"
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts "💬 #{block.text}"
      end
    end
  when ClaudeCodeSDK::ResultMessage
    puts "✅ Completed #{message.num_turns} turns - Cost: $#{message.total_cost_usd}"
  end
end
```

**Equivalent CLI command:**
```bash
echo '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Explain this code"}]}}' | claude -p --output-format=stream-json --input-format=stream-json --verbose
```

### 2. Auto-formatted Streaming

```ruby
# Automatic pretty-printing
ClaudeCodeSDK.stream_query(
  prompt: "Count from 1 to 5",
  options: ClaudeCodeOptions.new(max_turns: 1)
)
# Output:
# 💬 1 - The first number...
# 💬 2 - The second number...
# ✅ Cost: $0.002345
```

### 3. Custom Streaming with Block

```ruby
start_time = Time.now

ClaudeCodeSDK.stream_query(
  prompt: "Explain inheritance in Ruby"
) do |message, index|
  timestamp = Time.now - start_time
  
  case message
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts "[#{format('%.2f', timestamp)}s] #{block.text}"
      end
    end
  when ClaudeCodeSDK::ResultMessage
    puts "[#{format('%.2f', timestamp)}s] 💰 $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end
```

## Message Flow

Messages arrive in this typical order:

1. **SystemMessage** (`subtype: "init"`) - Session initialization with metadata
2. **AssistantMessage** - Claude's response with content blocks  
3. **ResultMessage** - Final statistics and cost information

### System Message (First)
```ruby
when ClaudeCodeSDK::SystemMessage
  if message.subtype == "init"
    puts "Session: #{message.data['session_id']}"
    puts "Model: #{message.data['model']}"
    puts "Tools: #{message.data['tools'].length} available"
    puts "MCP Servers: #{message.data['mcp_servers'].length}"
  end
```

### Assistant Message (Main Content)
```ruby
when ClaudeCodeSDK::AssistantMessage
  message.content.each do |block|
    case block
    when ClaudeCodeSDK::TextBlock
      puts "Text: #{block.text}"
    when ClaudeCodeSDK::ToolUseBlock
      puts "Tool: #{block.name} with #{block.input}"
    when ClaudeCodeSDK::ToolResultBlock
      puts "Result: #{block.content}"
    end
  end
```

### Result Message (Last)
```ruby
when ClaudeCodeSDK::ResultMessage
  puts "Duration: #{message.duration_ms}ms"
  puts "API Time: #{message.duration_api_ms}ms" 
  puts "Turns: #{message.num_turns}"
  puts "Cost: $#{message.total_cost_usd}"
  puts "Session: #{message.session_id}"
end
```

## MCP Streaming

MCP tool calls also stream in real-time:

```ruby
ClaudeCodeSDK.quick_mcp_query(
  "Use the about tool",
  server_name: "ninja",
  server_url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/",
  tools: "about"
).each do |message|
  case message
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      case block
      when ClaudeCodeSDK::TextBlock
        puts "📝 #{block.text}"
      when ClaudeCodeSDK::ToolUseBlock
        puts "🔧 Using: #{block.name}"
        puts "📥 Input: #{block.input}"
      when ClaudeCodeSDK::ToolResultBlock
        puts "📤 Result: #{block.content}"
      end
    end
  end
end
```

## Advanced Streaming Patterns

### Progress Tracking
```ruby
message_count = 0
total_text_length = 0

ClaudeCodeSDK.query(prompt: "Write a long story").each do |message|
  message_count += 1
  
  if message.is_a?(ClaudeCodeSDK::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        total_text_length += block.text.length
        puts "Progress: #{message_count} messages, #{total_text_length} characters"
      end
    end
  end
  
  # Early termination if needed
  break if total_text_length > 10000
end
```

### Error Handling During Streaming
```ruby
begin
  ClaudeCodeSDK.stream_query(prompt: "Complex operation") do |message, index|
    case message
    when ClaudeCodeSDK::ResultMessage
      if message.is_error
        puts "❌ Error detected: #{message.subtype}"
        # Handle error immediately
      end
    end
  end
rescue ClaudeCodeSDK::ProcessError => e
  puts "Process failed: #{e.message}"
rescue ClaudeCodeSDK::CLIJSONDecodeError => e
  puts "JSON parsing failed: #{e.message}"
end
```

### Tool Call Monitoring
```ruby
tool_calls = []

ClaudeCodeSDK.query(
  prompt: "Analyze this codebase using available tools",
  options: ClaudeCodeOptions.new(
    allowed_tools: ["Read", "Bash", "Grep"],
    max_turns: 5
  )
).each do |message|
  if message.is_a?(ClaudeCodeSDK::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::ToolUseBlock)
        tool_calls << { name: block.name, input: block.input, time: Time.now }
        puts "🔧 Tool #{tool_calls.length}: #{block.name}"
        
        # React to specific tools
        case block.name
        when "Bash"
          puts "   Running command: #{block.input['command']}"
        when "Read"
          puts "   Reading file: #{block.input['file_path']}"
        end
      end
    end
  end
end

puts "Total tools used: #{tool_calls.length}"
```

### Memory-Efficient Processing
```ruby
# Process large responses without storing everything in memory
text_chunks = []

ClaudeCodeSDK.query(prompt: "Generate a very long document").each do |message|
  if message.is_a?(ClaudeCodeSDK::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        # Process each chunk immediately
        process_text_chunk(block.text)
        
        # Only keep recent chunks in memory
        text_chunks << block.text
        text_chunks.shift if text_chunks.length > 10
      end
    end
  end
end
```

## Performance Benefits

- **Memory Efficient**: No need to collect all messages before processing
- **Responsive UI**: Immediate feedback for long-running operations  
- **Early Termination**: Stop processing when you have enough information
- **Real-time Monitoring**: Watch tool calls and results as they happen
- **Progress Tracking**: Monitor complex multi-step operations

## Rails Integration

For Rails applications, combine streaming with ActionCable for real-time WebSocket updates:

```ruby
# In a Sidekiq job
ClaudeCodeSDK.query(prompt: prompt, options: options).each do |message|
  ActionCable.server.broadcast("claude_#{user_id}", {
    type: 'claude_message',
    data: serialize_message(message),
    timestamp: Time.current
  })
end
```

See `examples/rails_sidekiq_example.rb` for a complete Rails + Sidekiq + ActionCable integration example.

## IRB Helpers

For quick testing in IRB:

```ruby
require_relative 'examples/irb_helpers'

# Auto-formatted streaming
auto_stream("Count to 5")

# Streaming with timestamps  
stream_claude("What is Ruby?")

# MCP streaming
ninja_test("Tell me about yourself")
```

The streaming support makes the Ruby SDK perfect for building responsive, interactive applications that provide immediate feedback to users.