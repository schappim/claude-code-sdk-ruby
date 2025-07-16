# frozen_string_literal: true

module ClaudeCode
  class ClaudeSDKError < StandardError
  end

  class CLIConnectionError < ClaudeSDKError
  end

  class CLINotFoundError < CLIConnectionError
    attr_reader :cli_path
    
    def initialize(message = "Claude Code not found", cli_path: nil)
      @cli_path = cli_path
      message = "#{message}: #{cli_path}" if cli_path
      super(message)
    end
  end

  class ProcessError < ClaudeSDKError
    attr_reader :exit_code, :stderr

    def initialize(message = "Process failed", exit_code: nil, stderr: nil)
      @exit_code = exit_code
      @stderr = stderr

      message = "#{message} (exit code: #{exit_code})" if exit_code
      message = "#{message}\nError output: #{stderr}" if stderr

      super(message)
    end
  end

  class CLIJSONDecodeError < ClaudeSDKError
    attr_reader :line, :original_error

    def initialize(line = nil, original_error = nil)
      @line = line
      @original_error = original_error
      
      msg = "Failed to decode JSON"
      msg += ": #{line[0, 100]}..." if line && !line.empty?
      msg += " (#{original_error.message})" if original_error
      
      super(msg)
    end
  end
end