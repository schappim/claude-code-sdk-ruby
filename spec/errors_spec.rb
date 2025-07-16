# frozen_string_literal: true

RSpec.describe ClaudeCodeSDK do
  describe 'error types' do
    describe ClaudeCodeSDK::ClaudeSDKError do
      it 'is a standard error' do
        expect(ClaudeCodeSDK::ClaudeSDKError.new).to be_a(StandardError)
      end
    end

    describe ClaudeCodeSDK::CLINotFoundError do
      it 'inherits from CLIConnectionError' do
        expect(ClaudeCodeSDK::CLINotFoundError.new).to be_a(ClaudeCodeSDK::CLIConnectionError)
      end

      it 'formats message with cli_path when provided' do
        error = ClaudeCodeSDK::CLINotFoundError.new("Not found", cli_path: "/usr/bin/claude")
        expect(error.message).to eq("Not found: /usr/bin/claude")
      end
    end

    describe ClaudeCodeSDK::ProcessError do
      it 'includes exit code and stderr in message' do
        error = ClaudeCodeSDK::ProcessError.new(
          "Command failed",
          exit_code: 1,
          stderr: "Error output"
        )
        
        expect(error.exit_code).to eq(1)
        expect(error.stderr).to eq("Error output")
        expect(error.message).to include("exit code: 1")
        expect(error.message).to include("Error output")
      end
    end

    describe ClaudeCodeSDK::CLIJSONDecodeError do
      it 'includes line and original error' do
        original = JSON::ParserError.new("Invalid JSON")
        error = ClaudeCodeSDK::CLIJSONDecodeError.new("invalid json line", original)
        
        expect(error.line).to eq("invalid json line")
        expect(error.original_error).to eq(original)
        expect(error.message).to include("Failed to decode JSON")
      end
    end
  end
end