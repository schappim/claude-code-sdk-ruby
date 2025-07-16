#!/usr/bin/env ruby
# Basic usage examples for Ruby Claude Code SDK

require_relative '../lib/claude_code_sdk'

def test_basic_query
  puts "=== Testing Basic Query ==="
  
  # Use the specific Claude path for your system
  claude_path = "/Users/admin/.claude/local/claude"
  
  begin
    ClaudeCodeSDK.query(
      prompt: "What is 2 + 2? Answer in one sentence.",
      cli_path: claude_path
    ).each do |message|
      puts "Message type: #{message.class}"
      
      if message.is_a?(ClaudeCodeSDK::AssistantMessage)
        message.content.each do |block|
          if block.is_a?(ClaudeCodeSDK::TextBlock)
            puts "Claude: #{block.text}"
          elsif block.is_a?(ClaudeCodeSDK::ToolUseBlock)
            puts "Tool Use: #{block.name} with input #{block.input}"
          end
        end
      elsif message.is_a?(ClaudeCodeSDK::ResultMessage)
        puts "Result: #{message.result}"
        puts "Cost: $#{message.total_cost_usd}" if message.total_cost_usd
      else
        puts "Other message: #{message.inspect}"
      end
    end
  rescue => e
    puts "Error: #{e.class} - #{e.message}"
    puts e.backtrace.first(5)
  end
end

def test_with_options
  puts "\n=== Testing with Options ==="
  
  claude_path = "/Users/admin/.claude/local/claude"
  
  options = ClaudeCodeSDK::ClaudeCodeOptions.new(
    max_turns: 1,
    system_prompt: "You are a helpful assistant. Be very concise."
  )
  
  begin
    ClaudeCodeSDK.query(
      prompt: "Explain Ruby in one sentence.",
      options: options,
      cli_path: claude_path
    ).each do |message|
      if message.is_a?(ClaudeCodeSDK::AssistantMessage)
        message.content.each do |block|
          if block.is_a?(ClaudeCodeSDK::TextBlock)
            puts "Claude: #{block.text}"
          end
        end
      end
    end
  rescue => e
    puts "Error: #{e.class} - #{e.message}"
    puts e.backtrace.first(5)
  end
end

if __FILE__ == $0
  test_basic_query
  test_with_options
end