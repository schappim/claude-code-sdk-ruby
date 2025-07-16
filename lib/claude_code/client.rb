# frozen_string_literal: true

require 'json'
require 'open3'
require 'pathname'

module ClaudeCode
  class Client
    def initialize
      # Client setup
    end

    def process_query(options:, prompt: nil, messages: nil, cli_path: nil, mcp_servers: {})
      if messages
        # Handle streaming JSON input
        transport = SubprocessCLITransport.new(prompt: '', options: options, cli_path: cli_path)
        transport.connect

        # Send messages
        transport.send_messages(messages)

        # Return enumerator for responses
        return Enumerator.new do |yielder|
          transport.receive_messages do |data|
            message = parse_message(data)
            yielder << message if message
          end
        ensure
          transport.disconnect
        end
      end

      transport = SubprocessCLITransport.new(prompt: prompt, options: options, cli_path: cli_path)

      transport.connect

      # Return lazy enumerator that streams messages as they arrive
      Enumerator.new do |yielder|
        transport.receive_messages do |data|
          message = parse_message(data)
          yielder << message if message
        end
      ensure
        transport.disconnect
      end
    end

    private

    def build_environment
      env = ENV.to_h
      env['CLAUDE_CODE_ENTRYPOINT'] = 'sdk-ruby'
      env['ANTHROPIC_API_KEY'] = ENV['ANTHROPIC_API_KEY'] if ENV['ANTHROPIC_API_KEY']
      env['CLAUDE_CODE_USE_BEDROCK'] = ENV['CLAUDE_CODE_USE_BEDROCK'] if ENV['CLAUDE_CODE_USE_BEDROCK']
      env['CLAUDE_CODE_USE_VERTEX'] = ENV['CLAUDE_CODE_USE_VERTEX'] if ENV['CLAUDE_CODE_USE_VERTEX']
      env
    end

    def parse_message(data)
      case data['type']
      when 'user'
        UserMessage.new(data.dig('message', 'content'))
      when 'assistant'
        content_blocks = []
        message_content = data.dig('message', 'content') || []
        message_content.each do |block|
          case block['type']
          when 'text'
            content_blocks << TextBlock.new(block['text'])
          when 'tool_use'
            content_blocks << ToolUseBlock.new(
              id: block['id'],
              name: block['name'],
              input: block['input']
            )
          when 'tool_result'
            content_blocks << ToolResultBlock.new(
              tool_use_id: block['tool_use_id'],
              content: block['content'],
              is_error: block['is_error']
            )
          end
        end
        AssistantMessage.new(content_blocks)
      when 'system'
        SystemMessage.new(
          subtype: data['subtype'],
          data: data
        )
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
      else
        nil
      end
    end
  end

  class SubprocessCLITransport
    MAX_BUFFER_SIZE = 1024 * 1024 * 50 # 50MB

    def initialize(prompt:, options:, cli_path: nil)
      @prompt = prompt
      @options = options
      @cli_path = cli_path
      @cwd = options.cwd&.to_s
      @process = nil
      @stdin = nil
      @stdout = nil
      @stderr = nil
    end

    def find_cli(cli_path = nil)
      # Use provided CLI path if valid
      if cli_path
        return cli_path if File.executable?(cli_path)

        raise CLINotFoundError.new("CLI not found at specified path: #{cli_path}", cli_path: cli_path)
      end

      # Try PATH first using cross-platform which
      cli = which('claude')
      return cli if cli

      # Try common locations
      locations = [
        Pathname.new(File.expand_path('~/.claude/local/claude')),
        Pathname.new(File.expand_path('~/.npm-global/bin/claude')),
        Pathname.new('/usr/local/bin/claude'),
        Pathname.new(File.expand_path('~/.local/bin/claude')),
        Pathname.new(File.expand_path('~/node_modules/.bin/claude')),
        Pathname.new(File.expand_path('~/.yarn/bin/claude'))
      ]

      locations.each do |path|
        return path.to_s if path.exist? && path.file?
      end

      # Check if Node.js is installed using cross-platform which
      node_installed = !which('node').nil?

      unless node_installed
        error_msg = <<~MSG
          Claude Code requires Node.js, which is not installed.

          📦 Install Node.js from: https://nodejs.org/

          After installing Node.js, install Claude Code:
            npm install -g @anthropic-ai/claude-code

          💡 For more installation options, see:
          https://docs.anthropic.com/en/docs/claude-code/quickstart
        MSG
        raise CLINotFoundError.new(error_msg)
      end

      # Node is installed but Claude Code isn't
      error_msg = <<~MSG
        Claude Code not found. Install with:
          npm install -g @anthropic-ai/claude-code

        📍 If already installed locally, try:
          export PATH="$HOME/node_modules/.bin:$PATH"

        🔧 Or specify the path when creating client:
          ClaudeCode.query(..., cli_path: '/path/to/claude')

        💡 For more installation options, see:
        https://docs.anthropic.com/en/docs/claude-code/quickstart
      MSG
      raise CLINotFoundError.new(error_msg)
    end

    # Cross-platform which command
    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        end
      end
      nil
    end

    def build_environment
      # Start with current environment
      env = ENV.to_h

      # Set SDK entrypoint identifier
      env['CLAUDE_CODE_ENTRYPOINT'] = 'sdk-ruby'

      # Ensure ANTHROPIC_API_KEY is available if set
      # This allows the CLI to authenticate with Anthropic's API
      env['ANTHROPIC_API_KEY'] = ENV['ANTHROPIC_API_KEY'] if ENV['ANTHROPIC_API_KEY']

      # Support for other authentication methods
      env['CLAUDE_CODE_USE_BEDROCK'] = ENV['CLAUDE_CODE_USE_BEDROCK'] if ENV['CLAUDE_CODE_USE_BEDROCK']

      env['CLAUDE_CODE_USE_VERTEX'] = ENV['CLAUDE_CODE_USE_VERTEX'] if ENV['CLAUDE_CODE_USE_VERTEX']

      env
    end

    def build_command
      # Determine output format (default to stream-json for SDK)
      output_format = @options.output_format || 'stream-json'
      cmd = [@cli_path, '--output-format', output_format, '--verbose']

      # Add input format if specified
      cmd.concat(['--input-format', @options.input_format]) if @options.input_format

      cmd.concat(['--system-prompt', @options.system_prompt]) if @options.system_prompt
      cmd.concat(['--append-system-prompt', @options.append_system_prompt]) if @options.append_system_prompt
      cmd.concat(['--allowedTools', @options.allowed_tools.join(',')]) unless @options.allowed_tools.empty?
      cmd.concat(['--max-turns', @options.max_turns.to_s]) if @options.max_turns
      cmd.concat(['--disallowedTools', @options.disallowed_tools.join(',')]) unless @options.disallowed_tools.empty?
      cmd.concat(['--model', @options.model]) if @options.model
      if @options.permission_prompt_tool_name
        cmd.concat(['--permission-prompt-tool',
                    @options.permission_prompt_tool_name])
      end
      cmd.concat(['--permission-mode', @options.permission_mode]) if @options.permission_mode
      cmd << '--continue' if @options.continue_conversation
      cmd.concat(['--resume', @options.resume]) if @options.resume

      unless @options.mcp_servers.empty?
        mcp_config = { 'mcpServers' => @options.mcp_servers.transform_values do |config|
          config.respond_to?(:to_h) ? config.to_h : config
        end }
        cmd.concat(['--mcp-config', JSON.generate(mcp_config)])
      end

      # For streaming JSON input, we use --print mode and send JSON via stdin
      # For regular input, we use --print with the prompt
      if @options.input_format == 'stream-json'
        cmd << '--print'
      else
        cmd.concat(['--print', @prompt])
      end

      cmd
    end

    def connect
      return if @process

      # Find CLI if not already set
      @cli_path ||= find_cli

      cmd = build_command
      puts "Debug: Connecting with command: #{cmd.join(' ')}" if ENV['DEBUG_CLAUDE_SDK']

      begin
        env = build_environment

        if @cwd
          @stdin, @stdout, @stderr, @process = Open3.popen3(env, *cmd, chdir: @cwd)
        else
          @stdin, @stdout, @stderr, @process = Open3.popen3(env, *cmd)
        end

        # Handle different input modes
        if @options.input_format == 'stream-json'
          # Keep stdin open for streaming JSON input
          puts 'Debug: Keeping stdin open for streaming JSON input' if ENV['DEBUG_CLAUDE_SDK']
        else
          # Close stdin for regular prompt mode
          @stdin.close
        end

        puts "Debug: Process started with PID #{@process.pid}" if ENV['DEBUG_CLAUDE_SDK']
      rescue Errno::ENOENT => e
        raise CLIConnectionError.new("Working directory does not exist: #{@cwd}") if @cwd && !Dir.exist?(@cwd)

        raise CLINotFoundError.new("Claude Code not found at: #{@cli_path}")
      rescue StandardError => e
        raise CLIConnectionError.new("Failed to start Claude Code: #{e.class} - #{e.message}")
      end
    end

    def disconnect
      return unless @process

      begin
        # Try to terminate gracefully
        if @process.alive?
          Process.kill('INT', @process.pid)

          # Wait for process to exit with timeout
          begin
            require 'timeout'
            Timeout.timeout(5) do
              @process.join
            end
          rescue Timeout::Error
            # Force kill if it doesn't exit gracefully
            begin
              Process.kill('KILL', @process.pid) if @process.alive?
              begin
                @process.join
              rescue StandardError
                nil
              end
            rescue Errno::ESRCH
              # Process already gone
            end
          end
        end
      rescue Errno::ESRCH, Errno::ECHILD
        # Process already gone
      ensure
        begin
          @stdin&.close
        rescue StandardError
          nil
        end
        begin
          @stdout&.close
        rescue StandardError
          nil
        end
        begin
          @stderr&.close
        rescue StandardError
          nil
        end
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @process = nil
      end
    end

    def receive_messages
      raise CLIConnectionError.new('Not connected') unless @process && @stdout

      json_buffer = ''

      begin
        @stdout.each_line do |line|
          line = line.strip
          next if line.empty?

          json_lines = line.split("\n")

          json_lines.each do |json_line|
            json_line = json_line.strip
            next if json_line.empty?

            json_buffer += json_line

            if json_buffer.length > MAX_BUFFER_SIZE
              json_buffer = ''
              raise CLIJSONDecodeError.new(
                "JSON message exceeded maximum buffer size of #{MAX_BUFFER_SIZE} bytes",
                StandardError.new("Buffer size #{json_buffer.length} exceeds limit #{MAX_BUFFER_SIZE}")
              )
            end

            begin
              data = JSON.parse(json_buffer)
              json_buffer = ''
              yield data
            rescue JSON::ParserError => e
              # For single-line JSON, if parsing fails, it's an error
              raise CLIJSONDecodeError.new(json_buffer, e) if json_buffer.include?("\n") || json_buffer.length > 10_000

              # Otherwise continue accumulating
              next
            end
          end
        end
      rescue IOError
        # Process has closed
      end

      # If there's still data in the buffer, it's invalid JSON
      if json_buffer && !json_buffer.strip.empty?
        # Try one more time to parse in case it's valid JSON
        begin
          data = JSON.parse(json_buffer)
          yield data
        rescue JSON::ParserError => e
          raise CLIJSONDecodeError.new(json_buffer, StandardError.new('Incomplete JSON at end of stream'))
        end
      end

      # Check for errors
      exit_code = @process.value.exitstatus if @process
      stderr_output = @stderr.read if @stderr

      return unless exit_code && exit_code != 0

      # Build helpful error message
      error_message = "Command failed with exit code #{exit_code}"
      
      if stderr_output.nil? || stderr_output.strip.empty?
        error_message += "\n\nNo error output from Claude CLI. Common causes:"
        error_message += "\n- Invalid or missing ANTHROPIC_API_KEY"
        error_message += "\n- MCP server connection failed"
        error_message += "\n- Network connectivity issues"
        error_message += "\n- Invalid model name or options"
        
        # Include debug info if available
        if ENV['DEBUG_CLAUDE_SDK']
          error_message += "\n\nDebug info:"
          error_message += "\n- CLI path: #{@cli_path}"
          error_message += "\n- Working directory: #{@cwd || 'current'}"
          error_message += "\n- JSON buffer (last #{[json_buffer.length, 200].min} chars): #{json_buffer[-200..-1]}" if json_buffer && !json_buffer.empty?
        end
        
        error_message += "\n\nTry enabling debug mode with ENV['DEBUG_CLAUDE_SDK'] = '1' for more details"
      else
        error_message += "\nError output: #{stderr_output}"
      end

      raise ProcessError.new(
        error_message,
        exit_code: exit_code,
        stderr: stderr_output
      )
    end

    def connected?
      @process && @process.alive?
    end

    # Send a JSON message via stdin for streaming input mode
    def send_message(message)
      raise CLIConnectionError.new('Not connected to CLI') unless @stdin

      json_line = message.to_json + "\n"
      puts "Debug: Sending JSON message: #{json_line.strip}" if ENV['DEBUG_CLAUDE_SDK']

      begin
        @stdin.write(json_line)
        @stdin.flush
      rescue Errno::EPIPE
        # Pipe is broken, process has terminated
        raise CLIConnectionError.new('CLI process terminated unexpectedly')
      end
    end

    # Send multiple messages and close stdin to signal end of input
    def send_messages(messages)
      raise CLIConnectionError.new('Not connected to CLI') unless @stdin

      messages.each do |message|
        send_message(message)
      end

      # Close stdin to signal end of input stream
      @stdin.close
      @stdin = nil
    end
  end
end
