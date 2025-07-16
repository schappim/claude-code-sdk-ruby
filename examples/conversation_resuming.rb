#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/claude_code_sdk'

# Example: Conversation resuming and continuation

puts "=== Conversation Resuming Example ==="

# Set your API key (you can also set this as an environment variable)
# ENV['ANTHROPIC_API_KEY'] = 'your-api-key-here'

# Start an initial conversation
puts "\n1. Starting initial conversation..."
session_id = nil

ClaudeCodeSDK.query("Hello! My name is John and I'm learning Ruby programming.") do |message|
  case message
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts "🤖 #{block.text}"
      end
    end
  when ClaudeCodeSDK::ResultMessage
    session_id = message.session_id
    puts "\n📋 Session ID: #{session_id}"
    puts "💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end

# Continue the most recent conversation (without session ID)
puts "\n2. Continuing the conversation..."
ClaudeCodeSDK.continue_conversation("What are some good Ruby resources for beginners?") do |message|
  case message
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts "🤖 #{block.text}"
      end
    end
  when ClaudeCodeSDK::ResultMessage
    puts "\n💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end

# Resume a specific conversation by session ID
if session_id
  puts "\n3. Resuming specific session: #{session_id}"
  ClaudeCodeSDK.resume_conversation(
    session_id,
    "Can you recommend a specific Ruby book?"
  ) do |message|
    case message
    when ClaudeCodeSDK::AssistantMessage
      message.content.each do |block|
        if block.is_a?(ClaudeCodeSDK::TextBlock)
          puts "🤖 #{block.text}"
        end
      end
    when ClaudeCodeSDK::ResultMessage
      puts "\n💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
    end
  end
end

# Continue with additional options
puts "\n4. Continuing with custom options..."
options = ClaudeCodeSDK::ClaudeCodeOptions.new(
  max_turns: 2,
  system_prompt: "You are a Ruby programming tutor. Keep responses concise and practical.",
  model: "claude-3-haiku"
)

ClaudeCodeSDK.continue_conversation(
  "Show me a simple Ruby class example", 
  options: options
) do |message|
  case message
  when ClaudeCodeSDK::AssistantMessage
    message.content.each do |block|
      if block.is_a?(ClaudeCodeSDK::TextBlock)
        puts "🤖 #{block.text}"
      end
    end
  when ClaudeCodeSDK::ResultMessage
    puts "\n💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end

puts "\n✅ Conversation resuming examples completed!"
puts "\nNotes:"
puts "- Set ANTHROPIC_API_KEY environment variable for authentication"
puts "- Session IDs are returned in ResultMessage.session_id"
puts "- Use continue_conversation() to continue the most recent session"
puts "- Use resume_conversation(session_id) to resume a specific session"