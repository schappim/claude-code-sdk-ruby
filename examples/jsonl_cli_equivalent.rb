#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/claude_code'

# Example: JSONL CLI equivalent showing how the Ruby SDK mirrors CLI functionality

puts "=== JSONL CLI Equivalent Example ==="

puts "\nThis example shows how the Ruby SDK implements the same functionality as:"
puts 'echo \'{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Explain this code"}]}}\' | claude -p --output-format=stream-json --input-format=stream-json --verbose'

# Create a single user message in the exact format the CLI expects
user_message = {
  'type' => 'user',
  'message' => {
    'role' => 'user',
    'content' => [
      {
        'type' => 'text',
        'text' => 'Explain this Ruby code: def factorial(n); n <= 1 ? 1 : n * factorial(n - 1); end'
      }
    ]
  }
}

puts "\n📝 Sending JSONL message:"
puts JSON.pretty_generate(user_message)

# Configure options to match CLI behavior
options = ClaudeCode::ClaudeCodeOptions.new(
  input_format: 'stream-json',
  output_format: 'stream-json'
)

puts "\n🚀 Processing with streaming JSON I/O..."

begin
  ClaudeCode.stream_json_query([user_message], options: options) do |message|
    case message
    when ClaudeCode::SystemMessage
      puts "🔧 System (#{message.subtype}): #{message.data.keys.join(', ')}"
    when ClaudeCode::AssistantMessage
      puts "\n💬 Assistant Response:"
      message.content.each do |block|
        case block
        when ClaudeCode::TextBlock
          puts block.text
        when ClaudeCode::ToolUseBlock
          puts "🔧 Tool Use: #{block.name}"
          puts "📥 Input: #{block.input}"
        when ClaudeCode::ToolResultBlock
          puts "📤 Tool Result: #{block.content}"
        end
      end
    when ClaudeCode::ResultMessage
      puts "\n📊 Result:"
      puts "  Duration: #{message.duration_ms}ms"
      puts "  API Time: #{message.duration_api_ms}ms" if message.duration_api_ms
      puts "  Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
      puts "  Turns: #{message.num_turns}"
      puts "  Session: #{message.session_id}"
      puts "  Status: #{message.subtype}"
    end
  end
rescue ClaudeCode::CLINotFoundError => e
  puts "❌ Claude CLI not found: #{e.message}"
  puts "\nPlease install Claude Code:"
  puts "  npm install -g @anthropic-ai/claude-code"
rescue ClaudeCode::ProcessError => e
  puts "❌ Process error: #{e.message}"
  puts "Exit code: #{e.exit_code}" if e.exit_code
  puts "Stderr: #{e.stderr}" if e.stderr
rescue StandardError => e
  puts "❌ Unexpected error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "="*50
puts "JSONL Helper Methods Demonstration"
puts "="*50

puts "\n1. Using JSONLHelpers.create_user_message:"
helper_message = ClaudeCode::JSONLHelpers.create_user_message("What is Ruby?")
puts JSON.pretty_generate(helper_message)

puts "\n2. Creating multiple messages:"
messages = ClaudeCode::JSONLHelpers.create_conversation(
  "Hello!",
  "How are you?",
  "Tell me about Ruby"
)

puts "Created #{messages.length} messages:"
messages.each_with_index do |msg, i|
  puts "Message #{i + 1}: #{msg['message']['content'][0]['text']}"
end

puts "\n3. Format as JSONL string:"
jsonl_string = ClaudeCode::JSONLHelpers.format_messages_as_jsonl(messages)
puts jsonl_string

puts "\n✅ CLI equivalent example completed!"
puts "\nTo use this functionality:"
puts "1. Set ANTHROPIC_API_KEY environment variable"
puts "2. Use ClaudeCode.stream_json_query(messages)"
puts "3. Process streaming responses in real-time"
puts "4. Handle system, assistant, and result messages appropriately"