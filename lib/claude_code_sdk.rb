# frozen_string_literal: true

require 'json'
require 'open3'
require 'pathname'

require_relative 'claude_code_sdk/version'
require_relative 'claude_code_sdk/types'
require_relative 'claude_code_sdk/errors'
require_relative 'claude_code_sdk/client'

module ClaudeCodeSDK
  # Main query method - supports both positional and keyword arguments
  def self.query(prompt_or_args = nil, prompt: nil, options: nil, cli_path: nil, mcp_servers: {}, &block)
    # Handle positional argument for backward compatibility
    if prompt_or_args.is_a?(String)
      prompt = prompt_or_args
    elsif prompt_or_args.is_a?(Hash)
      # Extract from hash if all args passed as first parameter
      prompt = prompt_or_args[:prompt] || prompt
      options = prompt_or_args[:options] || options
      cli_path = prompt_or_args[:cli_path] || cli_path
      mcp_servers = prompt_or_args[:mcp_servers] || mcp_servers
    end
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
    result = client.process_query(prompt: prompt, options: options, cli_path: cli_path, mcp_servers: mcp_servers)
    
    if block_given?
      result.each { |message| yield message }
    else
      result
    end
  end

  # Convenience method for adding MCP servers
  def self.add_mcp_server(name, config)
    { name => config }
  end

  # Ultra-convenient method for quick MCP queries
  def self.quick_mcp_query(prompt, server_name:, server_url:, tools:, **options)
    cli_path = options.delete(:cli_path)
    
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
      resume_conversation_id: session_id,
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
  def self.stream_json_query(messages, options: nil, cli_path: nil, mcp_servers: {}, &block)
    options ||= ClaudeCodeOptions.new
    
    # Set input_format to stream-json
    stream_options = ClaudeCodeOptions.new(
      allowed_tools: options.allowed_tools,
      max_thinking_tokens: options.max_thinking_tokens,
      system_prompt: options.system_prompt,
      append_system_prompt: options.append_system_prompt,
      mcp_tools: options.mcp_tools,
      mcp_servers: options.mcp_servers,
      permission_mode: options.permission_mode,
      continue_conversation: options.continue_conversation,
      resume_conversation_id: options.resume_conversation_id,
      max_turns: options.max_turns,
      disallowed_tools: options.disallowed_tools,
      model: options.model,
      permission_prompt_tool_name: options.permission_prompt_tool_name,
      cwd: options.cwd,
      input_format: 'stream-json'
    )
    
    # Use the client to process the query
    client = Client.new
    enumerator = client.process_query(messages: messages, options: stream_options, cli_path: cli_path, mcp_servers: mcp_servers)
    
    if block_given?
      enumerator.each { |message| yield message }
    else
      enumerator
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
        # Use auto_format_message for consistent formatting
        auto_format_message(message)
      end
    end
  end
  
  # Auto-format message for pretty printing
  def self.auto_format_message(message)
    case message
    when SystemMessage
      puts "🔧 System: #{message.subtype}" if message.subtype != "init"
    when AssistantMessage
      message.content.each do |block|
        case block
        when TextBlock
          puts "💬 #{block.text}"
        when ToolUseBlock
          puts "🔧 #{block.name}"
        when ToolResultBlock
          puts "📤 #{block.content}"
        end
      end
    when ResultMessage
      puts "✅ Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
    end
    $stdout.flush
  end
end