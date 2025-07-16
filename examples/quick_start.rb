#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/claude_code'

def basic_example
  puts "=== Basic Example ==="
  
  ClaudeCode.query(prompt: "What is 2 + 2?").each do |message|
    if message.is_a?(ClaudeCode::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "Claude: #{block.text}"
        end
      end
    end
  end
  puts
end

def with_options_example
  puts "=== With Options Example ==="
  
  options = ClaudeCode::ClaudeCodeOptions.new(
    system_prompt: "You are a helpful assistant that explains things simply.",
    max_turns: 1
  )
  
  ClaudeCode.query(
    prompt: "Explain what Ruby is in one sentence.", 
    options: options
  ).each do |message|
    if message.is_a?(ClaudeCode::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "Claude: #{block.text}"
        end
      end
    end
  end
  puts
end

def with_tools_example
  puts "=== With Tools Example ==="
  
  options = ClaudeCode::ClaudeCodeOptions.new(
    allowed_tools: ["Read", "Write"],
    system_prompt: "You are a helpful file assistant."
  )
  
  ClaudeCode.query(
    prompt: "Create a file called hello.txt with 'Hello, World!' in it",
    options: options
  ).each do |message|
    if message.is_a?(ClaudeCode::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "Claude: #{block.text}"
        end
      end
    elsif message.is_a?(ClaudeCode::ResultMessage) && message.total_cost_usd && message.total_cost_usd > 0
      puts "\nCost: $#{format('%.4f', message.total_cost_usd)}"
    end
  end
  puts
end

def main
  basic_example
  with_options_example
  with_tools_example
end

main if __FILE__ == $0