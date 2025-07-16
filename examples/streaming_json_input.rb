#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/claude_code'

# Example: Streaming JSON input for multi-turn conversations

puts "=== Streaming JSON Input Example ==="

# Set your API key
# ENV['ANTHROPIC_API_KEY'] = 'your-api-key-here'

puts "\n1. Multi-turn conversation using JSONL messages..."

# Create multiple user messages for a conversation
messages = [
  ClaudeCode::JSONLHelpers.create_user_message("Hello! I'm working on a Ruby project."),
  ClaudeCode::JSONLHelpers.create_user_message("Can you help me understand how modules work?"),
  ClaudeCode::JSONLHelpers.create_user_message("Show me a practical example of a module.")
]

puts "Sending #{messages.length} messages via streaming JSON input..."

begin
  ClaudeCode.stream_json_query(messages) do |message|
    case message
    when ClaudeCode::SystemMessage
      if message.subtype == 'init'
        puts "🔧 Session started: #{message.data['session_id']}"
        puts "🤖 Model: #{message.data['model']}"
      end
    when ClaudeCode::AssistantMessage
      message.content.each do |block|
        case block
        when ClaudeCode::TextBlock
          puts "💬 #{block.text}"
        when ClaudeCode::ToolUseBlock
          puts "🔧 Tool: #{block.name}"
          puts "📥 Input: #{block.input}"
        when ClaudeCode::ToolResultBlock
          puts "📤 Result: #{block.content}"
        end
      end
    when ClaudeCode::ResultMessage
      puts "\n✅ Conversation completed!"
      puts "📊 Duration: #{message.duration_ms}ms"
      puts "💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
      puts "🔄 Turns: #{message.num_turns}"
    end
  end
rescue ClaudeCode::CLINotFoundError => e
  puts "❌ Claude CLI not found: #{e.message}"
rescue ClaudeCode::ProcessError => e
  puts "❌ Process error: #{e.message}"
rescue StandardError => e
  puts "❌ Unexpected error: #{e.message}"
end

puts "\n2. Interactive conversation with streaming JSON..."

# Create a more complex conversation with different message types
conversation_messages = ClaudeCode::JSONLHelpers.create_conversation(
  "I need help with a Ruby script",
  "The script should read a CSV file and process the data",
  "Can you show me how to handle errors when reading the file?"
)

puts "Starting interactive conversation..."

ClaudeCode.stream_json_query(conversation_messages) do |message|
  case message
  when ClaudeCode::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCode::TextBlock)
        # Print text content with a slight delay to simulate real-time streaming
        puts "🤖 #{block.text}"
        sleep(0.1) if block.text.length > 100 # Slight delay for longer responses
      end
    end
  when ClaudeCode::ResultMessage
    puts "\n📋 Final Session: #{message.session_id}"
    puts "💰 Total Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end

puts "\n3. Custom JSONL format example..."

# Manually create JSONL format messages
custom_messages = [
  {
    'type' => 'user',
    'message' => {
      'role' => 'user',
      'content' => [
        {
          'type' => 'text',
          'text' => 'Explain Ruby metaprogramming in simple terms'
        }
      ]
    }
  },
  {
    'type' => 'user',
    'message' => {
      'role' => 'user',
      'content' => [
        {
          'type' => 'text',
          'text' => 'Give me a practical example I can try'
        }
      ]
    }
  }
]

puts "Using custom JSONL messages..."

ClaudeCode.stream_json_query(custom_messages) do |message|
  if message.is_a?(ClaudeCode::AssistantMessage)
    message.content.each do |block|
      if block.is_a?(ClaudeCode::TextBlock)
        puts "🎓 #{block.text}"
      end
    end
  end
end

puts "\n4. Streaming JSON with options..."

# Use streaming JSON with specific options
options = ClaudeCode::ClaudeCodeOptions.new(
  model: 'claude-3-haiku', # Use faster model for quick responses
  max_turns: 5,
  system_prompt: 'You are a Ruby programming tutor. Keep responses concise and practical.'
)

tutorial_messages = ClaudeCode::JSONLHelpers.create_conversation(
  "Teach me about Ruby blocks",
  "Show me different ways to use blocks",
  "What's the difference between blocks and procs?"
)

puts "Tutorial conversation with custom options..."

ClaudeCode.stream_json_query(tutorial_messages, options: options) do |message|
  case message
  when ClaudeCode::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCode::TextBlock)
        puts "👨‍🏫 #{block.text}"
      end
    end
  when ClaudeCode::ResultMessage
    puts "\n📚 Tutorial completed - Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end

puts "\n✅ Streaming JSON input examples completed!"
puts "\nKey features demonstrated:"
puts "- Multi-turn conversations via JSONL"
puts "- Real-time streaming responses"
puts "- Custom message creation with JSONLHelpers"
puts "- Manual JSONL format for advanced usage"
puts "- Integration with ClaudeCodeOptions"
puts "- Error handling for streaming conversations"

puts "\n💡 Use streaming JSON input when you need:"
puts "- Multiple conversation turns without restarting the CLI"
puts "- Interactive conversations with guidance during processing"
puts "- Complex multi-step conversations"
puts "- Efficient batch processing of conversation turns"