# frozen_string_literal: true

module ClaudeCode
  # Permission modes
  PERMISSION_MODES = %w[default acceptEdits bypassPermissions].freeze

  # Content block types
  class TextBlock
    attr_reader :text

    def initialize(text)
      @text = text
    end
  end

  class ToolUseBlock
    attr_reader :id, :name, :input

    def initialize(id:, name:, input:)
      @id = id
      @name = name
      @input = input
    end
  end

  class ToolResultBlock
    attr_reader :tool_use_id, :content, :is_error

    def initialize(tool_use_id:, content: nil, is_error: nil)
      @tool_use_id = tool_use_id
      @content = content
      @is_error = is_error
    end
  end

  # Base message class
  class BaseMessage
  end

  # Message types
  class UserMessage < BaseMessage
    attr_reader :content

    def initialize(content)
      @content = content
    end
  end

  class AssistantMessage < BaseMessage
    attr_reader :content

    def initialize(content)
      @content = content
    end
  end

  class SystemMessage < BaseMessage
    attr_reader :subtype, :data

    def initialize(subtype:, data:)
      @subtype = subtype
      @data = data
    end
  end

  class ResultMessage < BaseMessage
    attr_reader :subtype, :duration_ms, :duration_api_ms, :is_error, :num_turns, 
                :session_id, :total_cost_usd, :usage, :result

    def initialize(subtype:, duration_ms:, duration_api_ms: nil, is_error: false, num_turns:, 
                   session_id:, total_cost_usd: nil, usage: nil, result: nil)
      @subtype = subtype
      @duration_ms = duration_ms
      @duration_api_ms = duration_api_ms
      @is_error = is_error
      @num_turns = num_turns
      @session_id = session_id
      @total_cost_usd = total_cost_usd
      @usage = usage
      @result = result
    end
  end

  # MCP Server configurations
  class McpStdioServerConfig
    attr_reader :command, :args, :env, :type

    def initialize(command:, args: [], env: {}, type: 'stdio')
      @command = command
      @args = args
      @env = env
      @type = type
    end

    def to_h
      {
        type: @type,
        command: @command,
        args: @args,
        env: @env
      }
    end
  end

  class McpSSEServerConfig
    attr_reader :url, :headers, :type

    def initialize(url:, headers: {})
      @url = url
      @headers = headers
      @type = 'sse'
    end

    def to_h
      {
        type: @type,
        url: @url,
        headers: @headers
      }
    end
  end

  class McpHttpServerConfig
    attr_reader :url, :headers, :type

    def initialize(url:, headers: {})
      @url = url
      @headers = headers
      @type = 'http'
    end

    def to_h
      {
        type: @type,
        url: @url,
        headers: @headers
      }
    end
  end

  # JSONL message helpers for streaming input
  module JSONLHelpers
    # Create a user message in the format expected by Claude CLI
    def self.create_user_message(text)
      {
        'type' => 'user',
        'message' => {
          'role' => 'user',
          'content' => [
            {
              'type' => 'text',
              'text' => text
            }
          ]
        }
      }
    end

    # Format multiple messages as JSONL
    def self.format_messages_as_jsonl(messages)
      messages.map { |msg| msg.to_json }.join("\n")
    end

    # Create a multi-turn conversation as JSONL messages
    def self.create_conversation(*turns)
      turns.compact.reject(&:empty?).map { |turn| create_user_message(turn) }
    end
  end

  # Query options
  class ClaudeCodeOptions
    attr_reader :allowed_tools, :max_thinking_tokens, :system_prompt, :append_system_prompt,
                :mcp_tools, :mcp_servers, :permission_mode, :continue_conversation, :resume,
                :resume_conversation_id, :max_turns, :disallowed_tools, :model, :permission_prompt_tool_name, :cwd,
                :input_format, :output_format

    def initialize(
      allowed_tools: [],
      max_thinking_tokens: 8000,
      system_prompt: nil,
      append_system_prompt: nil,
      mcp_tools: [],
      mcp_servers: {},
      permission_mode: nil,
      continue_conversation: false,
      resume: nil,
      resume_conversation_id: nil,
      max_turns: nil,
      disallowed_tools: [],
      model: nil,
      permission_prompt_tool_name: nil,
      cwd: nil,
      input_format: nil,
      output_format: nil
    )
      @allowed_tools = allowed_tools
      @max_thinking_tokens = max_thinking_tokens
      @system_prompt = system_prompt
      @append_system_prompt = append_system_prompt
      @mcp_tools = mcp_tools
      @mcp_servers = mcp_servers
      @permission_mode = permission_mode
      @continue_conversation = continue_conversation
      @resume = resume
      @resume_conversation_id = resume_conversation_id
      @max_turns = max_turns
      @disallowed_tools = disallowed_tools
      @model = model
      @permission_prompt_tool_name = permission_prompt_tool_name
      @cwd = cwd
      @input_format = input_format
      @output_format = output_format
    end

    def to_h
      {
        allowed_tools: @allowed_tools,
        max_thinking_tokens: @max_thinking_tokens,
        system_prompt: @system_prompt,
        append_system_prompt: @append_system_prompt,
        mcp_tools: @mcp_tools,
        mcp_servers: @mcp_servers.transform_values { |config| config.respond_to?(:to_h) ? config.to_h : config },
        permission_mode: @permission_mode,
        continue_conversation: @continue_conversation,
        resume: @resume,
        resume_conversation_id: @resume_conversation_id,
        max_turns: @max_turns,
        disallowed_tools: @disallowed_tools,
        model: @model,
        permission_prompt_tool_name: @permission_prompt_tool_name,
        cwd: @cwd&.to_s,
        input_format: @input_format,
        output_format: @output_format
      }.compact
    end
  end
end