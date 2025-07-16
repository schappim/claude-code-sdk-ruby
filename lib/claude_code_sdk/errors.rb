# frozen_string_literal: true

module ClaudeCodeSDK
  class ClaudeSDKError < StandardError
  end

  class CLIConnectionError < ClaudeSDKError
  end

  class CLINotFoundError < CLIConnectionError
    def initialize(message = "Claude Code not found", cli_path: nil)
      message = "#{message}: #{cli_path}" if cli_path
      super(message)
    end
  end

  class ProcessError < ClaudeSDKError
    attr_reader :exit_code, :stderr

    def initialize(message, exit_code: nil, stderr: nil)
      @exit_code = exit_code
      @stderr = stderr

      message = "#{message} (exit code: #{exit_code})" if exit_code
      message = "#{message}\nError output: #{stderr}" if stderr

      super(message)
    end
  end

  class CLIJSONDecodeError < ClaudeSDKError
    attr_reader :line, :original_error

    def initialize(line, original_error)
      @line = line
      @original_error = original_error
      super("Failed to decode JSON: #{line[0, 100]}...")
    end
  end
end