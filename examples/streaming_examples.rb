#!/usr/bin/env ruby
# Streaming examples for Ruby Claude Code SDK

require_relative '../lib/claude_code'

def streaming_example
  claude_path = "/Users/admin/.claude/local/claude"
  
  puts "=== Streaming Messages Example ==="
  puts "Watch messages arrive in real-time!"
  puts
  
  options = ClaudeCode::ClaudeCodeOptions.new(
    model: "sonnet",
    max_turns: 1,
    system_prompt: "You are helpful. Provide detailed explanations."
  )
  
  start_time = Time.now
  message_count = 0
  
  ClaudeCode.query(
    prompt: "Explain how Ruby blocks work and give some examples",
    options: options,
    cli_path: claude_path
  ).each_with_index do |message, index|
    timestamp = Time.now - start_time
    message_count += 1
    
    puts "[#{format('%.3f', timestamp)}s] Message #{message_count}:"
    
    case message
    when ClaudeCode::SystemMessage
      puts "  🔧 SYSTEM: #{message.subtype}"
      if message.subtype == "init"
        puts "     Session: #{message.data['session_id']}"
        puts "     Model: #{message.data['model']}"
        puts "     Tools: #{message.data['tools'].length} available"
        puts "     MCP Servers: #{message.data['mcp_servers'].length}"
      end
      
    when ClaudeCode::UserMessage
      puts "  👤 USER: #{message.content[0, 50]}..."
      
    when ClaudeCode::AssistantMessage
      puts "  🤖 ASSISTANT:"
      message.content.each do |block|
        case block
        when ClaudeCode::TextBlock
          # Stream text in chunks to show real-time effect
          text = block.text
          if text.length > 100
            puts "     💬 #{text[0, 100]}..."
            puts "        (#{text.length} total characters)"
          else
            puts "     💬 #{text}"
          end
          
        when ClaudeCode::ToolUseBlock
          puts "     🔧 TOOL: #{block.name}"
          puts "        Input: #{block.input}"
          
        when ClaudeCode::ToolResultBlock
          puts "     📤 RESULT: #{block.content}"
        end
      end
      
    when ClaudeCode::ResultMessage
      puts "  ✅ RESULT: #{message.subtype}"
      puts "     Duration: #{message.duration_ms}ms (API: #{message.duration_api_ms}ms)"
      puts "     Turns: #{message.num_turns}"
      puts "     Cost: $#{format('%.6f', message.total_cost_usd)}" if message.total_cost_usd
      puts "     Session: #{message.session_id}"
      if message.result
        puts "     Final: #{message.result[0, 100]}..."
      end
    end
    
    puts
    $stdout.flush # Ensure immediate output
  end
  
  total_time = Time.now - start_time
  puts "🏁 Streaming completed in #{format('%.3f', total_time)}s with #{message_count} messages"
end

def streaming_mcp_example
  puts "\n" + "="*60 + "\n"
  puts "=== Streaming MCP Example ==="
  puts
  
  start_time = Time.now
  
  ClaudeCode.quick_mcp_query(
    "Use the about tool and then explain what you learned about this MCP server",
    server_name: "ninja",
    server_url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/",
    tools: "about",
    max_turns: 1
  ).each_with_index do |message, index|
    timestamp = Time.now - start_time
    
    case message
    when ClaudeCode::SystemMessage
      puts "[#{format('%.3f', timestamp)}s] 🔧 System init - MCP servers: #{message.data['mcp_servers'].length}"
      
    when ClaudeCode::AssistantMessage
      puts "[#{format('%.3f', timestamp)}s] 🤖 Assistant response:"
      message.content.each do |block|
        case block
        when ClaudeCode::TextBlock
          puts "   💬 #{block.text}"
        when ClaudeCode::ToolUseBlock
          puts "   🔧 Using tool: #{block.name}"
          puts "   📥 Input: #{block.input}"
        when ClaudeCode::ToolResultBlock
          puts "   📤 Tool result received"
        end
      end
      
    when ClaudeCode::ResultMessage
      puts "[#{format('%.3f', timestamp)}s] ✅ Final result - Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
    end
    
    $stdout.flush
  end
end

def simple_streaming_examples
  puts "\n" + "="*60 + "\n"
  puts "=== Simple Streaming Examples ==="
  puts

  # Example 1: Default streaming output
  puts "1. Default streaming (auto-formatted):"
  ClaudeCode.stream_query(
    prompt: "Count from 1 to 3 and explain each number",
    options: ClaudeCode::ClaudeCodeOptions.new(
      model: "sonnet",
      max_turns: 1
    ),
    cli_path: "/Users/admin/.claude/local/claude"
  )

  puts "\n" + "="*50 + "\n"

  # Example 2: Custom streaming with block
  puts "2. Custom streaming with timestamps:"
  start_time = Time.now

  ClaudeCode.stream_query(
    prompt: "What is Ruby?",
    options: ClaudeCode::ClaudeCodeOptions.new(max_turns: 1),
    cli_path: "/Users/admin/.claude/local/claude"
  ) do |message, index|
    timestamp = Time.now - start_time
    
    case message
    when ClaudeCode::AssistantMessage
      message.content.each do |block|
        if block.is_a?(ClaudeCode::TextBlock)
          puts "[#{format('%.2f', timestamp)}s] #{block.text}"
        end
      end
    when ClaudeCode::ResultMessage
      puts "[#{format('%.2f', timestamp)}s] 💰 $#{format('%.6f', message.total_cost_usd || 0)}"
    end
  end
end

def show_streaming_benefits
  puts "=== Benefits of Streaming ==="
  puts
  puts "✅ Real-time feedback - see messages as they arrive"
  puts "✅ Lower memory usage - process messages one by one"
  puts "✅ Better user experience - immediate response indication"
  puts "✅ Early error detection - catch issues quickly"
  puts "✅ Progress tracking - monitor long-running operations"
  puts
  puts "Perfect for:"
  puts "• Interactive applications"
  puts "• Long-running code generation"
  puts "• Tool-heavy workflows"
  puts "• Real-time monitoring"
  puts
  puts "="*60
  puts
end

if __FILE__ == $0
  show_streaming_benefits
  streaming_example
  streaming_mcp_example
  simple_streaming_examples
end