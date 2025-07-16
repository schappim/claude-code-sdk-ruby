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

  # Continue the most recent conversation
  def self.continue_conversation(prompt = nil, options: nil, cli_path: nil, mcp_servers: {})
    options ||= ClaudeCodeOptions.new
    
    # Set continue_conversation to true
    continue_options = ClaudeCodeOptions.new(
      allowed_tools: options.allowed_tools,
      max_thinking_tokens: options.max_thinking_tokens,
      system_prompt: options.system_prompt,
      append_system_prompt: options.append_system_prompt,
      mcp_tools: options.mcp_tools,
      mcp_servers: options.mcp_servers,
      permission_mode: options.permission_mode,
      continue_conversation: true,
      resume: options.resume,
      max_turns: options.max_turns,
      disallowed_tools: options.disallowed_tools,
      model: options.model,
      permission_prompt_tool_name: options.permission_prompt_tool_name,
      cwd: options.cwd
    )
    
    query(
      prompt: prompt || "",
      options: continue_options,
      cli_path: cli_path,
      mcp_servers: mcp_servers
    )
  end
  
  # Resume a specific conversation by session ID
  def self.resume_conversation(session_id, prompt = nil, options: nil, cli_path: nil, mcp_servers: {})
    options ||= ClaudeCodeOptions.new
    
    # Set resume with the session ID
    resume_options = ClaudeCodeOptions.new(
      allowed_tools: options.allowed_tools,
      max_thinking_tokens: options.max_thinking_tokens,
      system_prompt: options.system_prompt,
      append_system_prompt: options.append_system_prompt,
      mcp_tools: options.mcp_tools,
      mcp_servers: options.mcp_servers,
      permission_mode: options.permission_mode,
      continue_conversation: options.continue_conversation,
      resume: session_id,
      max_turns: options.max_turns,
      disallowed_tools: options.disallowed_tools,
      model: options.model,
      permission_prompt_tool_name: options.permission_prompt_tool_name,
      cwd: options.cwd
    )
    
    query(
      prompt: prompt || "",
      options: resume_options,
      cli_path: cli_path,
      mcp_servers: mcp_servers
    )
  end

  # Query with streaming JSON input (multiple turns via JSONL)
  def self.stream_json_query(messages, options: nil, cli_path: nil, mcp_servers: {})
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
        cwd: options.cwd,
        input_format: 'stream-json',
        output_format: 'stream-json'
      )
    else
      # Ensure we're using streaming JSON input and output
      options = ClaudeCodeOptions.new(
        allowed_tools: options.allowed_tools,
        max_thinking_tokens: options.max_thinking_tokens,
        system_prompt: options.system_prompt,
        append_system_prompt: options.append_system_prompt,
        mcp_tools: options.mcp_tools,
        mcp_servers: options.mcp_servers,
        permission_mode: options.permission_mode,
        continue_conversation: options.continue_conversation,
        resume: options.resume,
        max_turns: options.max_turns,
        disallowed_tools: options.disallowed_tools,
        model: options.model,
        permission_prompt_tool_name: options.permission_prompt_tool_name,
        cwd: options.cwd,
        input_format: 'stream-json',
        output_format: 'stream-json'
      )
    end
    
    ENV['CLAUDE_CODE_ENTRYPOINT'] = 'sdk-ruby'
    
    # Create transport directly for streaming JSON input
    transport = SubprocessCLITransport.new(prompt: "", options: options, cli_path: cli_path)
    
    begin
      transport.connect
      
      # Send messages via stdin
      transport.send_messages(messages)
      
      # Return enumerator for streaming responses
      Enumerator.new do |yielder|
        transport.receive_messages do |data|
          # Parse messages directly since we don't need the full client here
          message = parse_cli_message(data)
          yielder << message if message
        end
      end
    ensure
      transport.disconnect
    end
  end

  # Helper method to parse CLI messages for streaming JSON input
  def self.parse_cli_message(data)
    case data['type']
    when 'user'
      UserMessage.new(data.dig('message', 'content'))
    when 'assistant'
      content_blocks = parse_content_blocks(data.dig('message', 'content') || [])
      AssistantMessage.new(content_blocks)
    when 'system'
      SystemMessage.new(subtype: data['subtype'], data: data)
    when 'result'
      ResultMessage.new(
        subtype: data['subtype'],
        duration_ms: data['duration_ms'],
        duration_api_ms: data['duration_api_ms'],
        is_error: data['is_error'],
        num_turns: data['num_turns'],
        session_id: data['session_id'],
        total_cost_usd: data['total_cost_usd'],
        usage: data['usage'],
        result: data['result']
      )
    end
  end

  # Helper method to parse content blocks
  def self.parse_content_blocks(blocks)
    blocks.map do |block|
      case block['type']
      when 'text'
        TextBlock.new(block['text'])
      when 'tool_use'
        ToolUseBlock.new(id: block['id'], name: block['name'], input: block['input'])
      when 'tool_result'
        ToolResultBlock.new(
          tool_use_id: block['tool_use_id'],
          content: block['content'],
          is_error: block['is_error']
        )
      end
    end.compact
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