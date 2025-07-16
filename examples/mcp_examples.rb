#!/usr/bin/env ruby
# MCP server configuration examples for Ruby Claude Code SDK

require_relative '../lib/claude_code_sdk'

def test_mcp_creator_ninja
  claude_path = "/Users/admin/.claude/local/claude"
  
  puts "=== Testing MCP Creator Ninja Server ==="
  puts
  
  # Method 1: Using the ergonomic mcp_servers parameter
  puts "1. Using ergonomic mcp_servers parameter:"
  
  mcp_servers = ClaudeCodeSDK.add_mcp_server(
    "creator_ninja", 
    "https://mcp-creator-ninja-v1-4-0.mcp.soy/"
  )
  
  options = ClaudeCodeSDK::ClaudeCodeOptions.new(
    max_turns: 1,
    allowed_tools: ["mcp__creator_ninja__about"], # Allow the 'about' tool
    system_prompt: "You are helpful. Use the MCP tools available to you."
  )
  
  begin
    ClaudeCodeSDK.query(
      prompt: "Use the about tool to tell me about the Creator Ninja MCP server",
      options: options,
      cli_path: claude_path,
      mcp_servers: mcp_servers
    ).each do |message|
      case message
      when ClaudeCodeSDK::AssistantMessage
        message.content.each do |block|
          case block
          when ClaudeCodeSDK::TextBlock
            puts "   Response: #{block.text}"
          when ClaudeCodeSDK::ToolUseBlock
            puts "   Tool Used: #{block.name}"
            puts "   Tool Input: #{block.input}"
          end
        end
      when ClaudeCodeSDK::ResultMessage
        puts "   Cost: $#{format('%.6f', message.total_cost_usd)}" if message.total_cost_usd
      end
    end
  rescue => e
    puts "   Error: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
  
  puts "\n" + "="*60 + "\n"
  
  # Method 2: Using options directly
  puts "2. Using ClaudeCodeOptions directly:"
  
  creator_ninja_server = ClaudeCodeSDK::McpHttpServerConfig.new(
    url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/"
  )
  
  options2 = ClaudeCodeSDK::ClaudeCodeOptions.new(
    max_turns: 1,
    mcp_servers: { "creator_ninja" => creator_ninja_server },
    allowed_tools: ["mcp__creator_ninja__about"],
    system_prompt: "You are helpful. Call the about tool to learn about yourself."
  )
  
  begin
    ClaudeCodeSDK.query(
      prompt: "What can you tell me about yourself using the about tool?",
      options: options2,
      cli_path: claude_path
    ).each do |message|
      case message
      when ClaudeCodeSDK::AssistantMessage
        message.content.each do |block|
          case block
          when ClaudeCodeSDK::TextBlock
            puts "   Response: #{block.text}"
          when ClaudeCodeSDK::ToolUseBlock
            puts "   Tool Used: #{block.name}"
            puts "   Tool Input: #{block.input}"
          end
        end
      when ClaudeCodeSDK::ResultMessage
        puts "   Cost: $#{format('%.6f', message.total_cost_usd)}" if message.total_cost_usd
      end
    end
  rescue => e
    puts "   Error: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
end

def test_ultra_convenient_method
  puts "=== Ultra-Convenient MCP Method ==="
  puts
  
  # The simplest way to use MCP - just specify server and tools
  ClaudeCodeSDK.quick_mcp_query(
    "Tell me about this MCP server using the about tool",
    server_name: "ninja",
    server_url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/",
    tools: "about"  # Can be string or array
  ).each do |message|
    if message.is_a?(ClaudeCodeSDK::AssistantMessage)
      message.content.each do |block|
        if block.is_a?(ClaudeCodeSDK::TextBlock)
          puts "Response: #{block.text}"
        elsif block.is_a?(ClaudeCodeSDK::ToolUseBlock)
          puts "🔧 Tool: #{block.name}"
        end
      end
    end
  end
  
  puts "\n" + "="*50 + "\n"
end

def show_mcp_usage_examples
  puts "=== MCP Server Configuration Examples ==="
  puts
  puts "```ruby"
  puts "# Method 1: Using ergonomic helper"
  puts "mcp_servers = ClaudeCodeSDK.add_mcp_server("
  puts "  'my_server', 'https://my-mcp-server.com/'"
  puts ")"
  puts
  puts "ClaudeCodeSDK.query("
  puts "  prompt: 'Use my_server tools',"
  puts "  mcp_servers: mcp_servers,"
  puts "  options: ClaudeCodeOptions.new("
  puts "    allowed_tools: ['mcp__my_server__my_tool']"
  puts "  )"
  puts ")"
  puts
  puts "# Method 2: Using configuration objects"
  puts "options = ClaudeCodeSDK::ClaudeCodeOptions.new("
  puts "  mcp_servers: {"
  puts "    'http_server' => ClaudeCodeSDK::McpHttpServerConfig.new("
  puts "      url: 'https://api.example.com'"
  puts "    ),"
  puts "    'stdio_server' => ClaudeCodeSDK::McpStdioServerConfig.new("
  puts "      command: 'node',"
  puts "      args: ['my-mcp-server.js']"
  puts "    )"
  puts "  },"
  puts "  allowed_tools: ['mcp__http_server__api_call']"
  puts ")"
  puts
  puts "# Method 3: Multiple servers with helper"
  puts "servers = {}"
  puts "servers.merge!(ClaudeCodeSDK.add_mcp_server('ninja', 'https://...'))"
  puts "servers.merge!(ClaudeCodeSDK.add_mcp_server('local', 'node server.js'))"
  puts "```"
  puts
  puts "="*60
  puts
end

if __FILE__ == $0
  show_mcp_usage_examples
  test_ultra_convenient_method
  test_mcp_creator_ninja
end