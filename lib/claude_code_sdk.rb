# frozen_string_literal: true

require 'json'
require 'open3'
require 'pathname'

require_relative 'claude_code_sdk/version'
require_relative 'claude_code_sdk/types'
require_relative 'claude_code_sdk/errors'
require_relative 'claude_code_sdk/client'

module ClaudeCodeSDK
  def self.query(prompt:, options: nil, cli_path: nil, mcp_servers: {})
    options ||= ClaudeCodeOptions.new
    
    # Merge MCP servers if provided as a separate parameter
    unless mcp_servers.empty?
      options = ClaudeCodeOptions.new(
        allowed_tools: options.allowed_tools,
        max_thinking_tokens: options.max_thinking_tokens,
        system_prompt: options.system_prompt,
        append_system_prompt: options.append_system_prompt,
        mcp_tools: options.mcp_tools,
        mcp_servers: options.mcp_servers.merge(mcp_servers),
        permission_mode: options.permission_mode,
        continue_conversation: options.continue_conversation,
        resume: options.resume,
        max_turns: options.max_turns,
        disallowed_tools: options.disallowed_tools,
        model: options.model,
        permission_prompt_tool_name: options.permission_prompt_tool_name,
        cwd: options.cwd
      )
    end
    
    ENV['CLAUDE_CODE_ENTRYPOINT'] = 'sdk-ruby'
    
    client = Client.new
    client.process_query(prompt: prompt, options: options, cli_path: cli_path)
  end

  # Convenience method for adding MCP servers
  def self.add_mcp_server(name, config)
    case config
    when String
      # HTTP/SSE URL
      if config.start_with?('http')
        { name => McpHttpServerConfig.new(url: config) }
      else
        # Command string
        { name => McpStdioServerConfig.new(command: config) }
      end
    when Hash
      if config[:type] == 'http' || config['type'] == 'http'
        { name => McpHttpServerConfig.new(url: config[:url] || config['url'], headers: config[:headers] || config['headers'] || {}) }
      elsif config[:type] == 'sse' || config['type'] == 'sse'
        { name => McpSSEServerConfig.new(url: config[:url] || config['url'], headers: config[:headers] || config['headers'] || {}) }
      else
        { name => McpStdioServerConfig.new(
          command: config[:command] || config['command'],
          args: config[:args] || config['args'] || [],
          env: config[:env] || config['env'] || {}
        )}
      end
    else
      raise ArgumentError, "Invalid MCP server config: #{config}"
    end
  end

  # Ultra-convenient method for quick MCP queries
  def self.quick_mcp_query(prompt, server_name:, server_url:, tools:, **options)
    cli_path = options.delete(:cli_path) || "/Users/admin/.claude/local/claude"
    
    mcp_servers = add_mcp_server(server_name, server_url)
    
    # Ensure tools are in the correct format
    allowed_tools = Array(tools).map { |tool|
      tool.start_with?("mcp__") ? tool : "mcp__#{server_name}__#{tool}"
    }
    
    opts = ClaudeCodeOptions.new(
      allowed_tools: allowed_tools,
      max_turns: options[:max_turns] || 1,
      system_prompt: options[:system_prompt] || "You are helpful. Use the available MCP tools to answer questions.",
      **options.slice(:model, :permission_mode, :cwd)
    )
    
    query(
      prompt: prompt,
      options: opts,
      cli_path: cli_path,
      mcp_servers: mcp_servers
    )
  end

  # Streaming helper that prints messages as they arrive
  def self.stream_query(prompt:, options: nil, cli_path: nil, mcp_servers: {}, &block)
    query(
      prompt: prompt,
      options: options,
      cli_path: cli_path,
      mcp_servers: mcp_servers
    ).each_with_index do |message, index|
      if block_given?
        yield message, index
      else
        # Default streaming output
        case message
        when SystemMessage
          puts "🔧 System: #{message.subtype}" if message.subtype != "init"
        when AssistantMessage
          message.content.each do |block|
            case block
            when TextBlock
              puts "💬 #{block.text}"
            when ToolUseBlock
              puts "🔧 #{block.name}: #{block.input}"
            end
          end
        when ResultMessage
          puts "✅ Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
        end
        $stdout.flush
      end
    end
  end
end