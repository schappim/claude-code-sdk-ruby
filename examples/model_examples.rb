#!/usr/bin/env ruby
# Model specification examples for Ruby Claude Code SDK

require_relative '../lib/claude_code'

def test_model_specification
  claude_path = "/Users/admin/.claude/local/claude"
  
  puts "=== Model Specification Examples ==="
  puts
  
  # Example 1: Using model alias
  puts "1. Using model alias 'sonnet':"
  options1 = ClaudeCode::ClaudeCodeOptions.new(
    model: "sonnet",
    max_turns: 1
  )
  
  ClaudeCode.query(
    prompt: "What's the capital of Japan?",
    options: options1,
    cli_path: claude_path
  ).each do |message|
    if message.is_a?(ClaudeCode::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "   Answer: #{block.text}"
        end
      end
    end
  end
  
  puts
  
  # Example 2: Using full model name
  puts "2. Using full model name 'claude-sonnet-4-20250514':"
  options2 = ClaudeCode::ClaudeCodeOptions.new(
    model: "claude-sonnet-4-20250514",
    system_prompt: "Be very concise.",
    max_turns: 1
  )
  
  ClaudeCode.query(
    prompt: "What's 10 + 15?",
    options: options2,
    cli_path: claude_path
  ).each do |message|
    if message.is_a?(ClaudeCode::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "   Answer: #{block.text}"
        end
      end
    end
  end
  
  puts
  
  # Example 3: No model specified (uses default)
  puts "3. Using default model (no model specified):"
  options3 = ClaudeCode::ClaudeCodeOptions.new(
    max_turns: 1
  )
  
  ClaudeCode.query(
    prompt: "What's the largest planet in our solar system?",
    options: options3,
    cli_path: claude_path
  ).each do |message|
    if message.is_a?(ClaudeCode::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "   Answer: #{block.text}"
        end
      end
    end
  end
end

def show_usage
  puts "=== How to Specify Models in Ruby Claude SDK ==="
  puts
  puts "```ruby"
  puts "# Using model alias (recommended)"
  puts "options = ClaudeCode::ClaudeCodeOptions.new("
  puts "  model: 'sonnet',  # or 'haiku', 'opus'"
  puts "  max_turns: 1"
  puts ")"
  puts
  puts "# Using full model name"
  puts "options = ClaudeCode::ClaudeCodeOptions.new("
  puts "  model: 'claude-sonnet-4-20250514',"
  puts "  system_prompt: 'You are helpful.'"
  puts ")"
  puts
  puts "# Query with model"
  puts "ClaudeCode.query("
  puts "  prompt: 'Your question here',"
  puts "  options: options,"
  puts "  cli_path: '/path/to/claude'"
  puts ")"
  puts "```"
  puts
  puts "="*50
  puts
end

if __FILE__ == $0
  show_usage
  test_model_specification
end