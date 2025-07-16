# IRB helpers for Ruby Claude Code SDK with MCP
# Load this file: require_relative 'examples/irb_helpers'

require_relative '../lib/claude_code_sdk'

# Quick MCP test with Creator Ninja
def ninja_test(prompt)
  ClaudeCodeSDK.quick_mcp_query(
    prompt,
    server_name: 'ninja',
    server_url: 'https://mcp-creator-ninja-v1-4-0.mcp.soy/',
    tools: 'about'
  ).each do |msg|
    case msg
    when ClaudeCodeSDK::AssistantMessage
      msg.content.each do |block|
        case block
        when ClaudeCodeSDK::TextBlock
          puts "💬 #{block.text}"
        when ClaudeCodeSDK::ToolUseBlock
          puts "🔧 #{block.name}: #{block.input}"
        end
      end
    when ClaudeCodeSDK::ResultMessage
      puts "💰 $#{format('%.6f', msg.total_cost_usd)}" if msg.total_cost_usd
    end
  end
end

# Generic MCP tester
def test_mcp(prompt, server_name, server_url, tools)
  ClaudeCodeSDK.quick_mcp_query(
    prompt,
    server_name: server_name,
    server_url: server_url,
    tools: tools
  ).each { |msg| puts msg.inspect }
end

# Quick Claude query without MCP
def quick_claude(prompt, model: nil)
  options = ClaudeCodeSDK::ClaudeCodeOptions.new(
    model: model,
    max_turns: 1
  )
  
  ClaudeCodeSDK.query(
    prompt: prompt,
    options: options,
    cli_path: "/Users/admin/.claude/local/claude"
  ).each do |msg|
    if msg.is_a?(ClaudeCodeSDK::AssistantMessage)
      msg.content.each do |block|
        if block.is_a?(ClaudeCodeSDK::TextBlock)
          puts block.text
        end
      end
    end
  end
end

# Streaming version with timestamps
def stream_claude(prompt, model: nil)
  start_time = Time.now
  ClaudeCodeSDK.stream_query(
    prompt: prompt,
    options: ClaudeCodeSDK::ClaudeCodeOptions.new(model: model, max_turns: 1),
    cli_path: "/Users/admin/.claude/local/claude"
  ) do |msg, index|
    timestamp = Time.now - start_time
    case msg
    when ClaudeCodeSDK::AssistantMessage
      msg.content.each do |block|
        if block.is_a?(ClaudeCodeSDK::TextBlock)
          puts "[#{format('%.2f', timestamp)}s] #{block.text}"
        end
      end
    when ClaudeCodeSDK::ResultMessage
      puts "[#{format('%.2f', timestamp)}s] 💰 $#{format('%.6f', msg.total_cost_usd || 0)}"
    end
  end
end

# Simple auto-streaming
def auto_stream(prompt, model: nil)
  ClaudeCodeSDK.stream_query(
    prompt: prompt,
    options: ClaudeCodeSDK::ClaudeCodeOptions.new(model: model, max_turns: 1),
    cli_path: "/Users/admin/.claude/local/claude"
  )
end

puts "🚀 Ruby Claude Code SDK with MCP and Streaming helpers loaded!"
puts
puts "Basic commands:"
puts "  quick_claude('What is Ruby?')"
puts "  ninja_test('Tell me about yourself')"
puts
puts "Streaming commands:"
puts "  stream_claude('Explain Ruby blocks')"
puts "  auto_stream('Count to 5')"
puts
puts "Advanced:"
puts "  quick_claude('Explain arrays', model: 'sonnet')"
puts "  test_mcp('prompt', 'server_name', 'server_url', 'tool_name')"