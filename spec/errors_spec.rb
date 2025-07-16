# frozen_string_literal: true

RSpec.describe ClaudeCodeSDK do
  describe 'error types' do
    describe ClaudeCodeSDK::ClaudeSDKError do
      it 'is a standard error' do
        expect(ClaudeCodeSDK::ClaudeSDKError.new).to be_a(StandardError)
      end

      it 'accepts custom message' do
        error = ClaudeCodeSDK::ClaudeSDKError.new('Custom error message')
        expect(error.message).to eq('Custom error message')
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

      it 'provides helpful default message' do
        error = ClaudeCodeSDK::CLINotFoundError.new
        expect(error.message).to include('Claude Code not found')
      end

      it 'stores cli_path attribute' do
        error = ClaudeCodeSDK::CLINotFoundError.new('Test', cli_path: '/test/path')
        expect(error.cli_path).to eq('/test/path')
      end
    end

    describe ClaudeCodeSDK::CLIConnectionError do
      it 'inherits from ClaudeSDKError' do
        expect(ClaudeCodeSDK::CLIConnectionError.new).to be_a(ClaudeCodeSDK::ClaudeSDKError)
      end

      it 'accepts custom message' do
        error = ClaudeCodeSDK::CLIConnectionError.new('Connection failed')
        expect(error.message).to eq('Connection failed')
      end
    end

    describe ClaudeCodeSDK::ProcessError do
      it 'inherits from ClaudeSDKError' do
        expect(ClaudeCodeSDK::ProcessError.new).to be_a(ClaudeCodeSDK::ClaudeSDKError)
      end

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

      it 'works without optional parameters' do
        error = ClaudeCodeSDK::ProcessError.new('Process failed')
        
        expect(error.message).to eq('Process failed')
        expect(error.exit_code).to be_nil
        expect(error.stderr).to be_nil
      end

      it 'handles exit code without stderr' do
        error = ClaudeCodeSDK::ProcessError.new('Failed', exit_code: 2)
        
        expect(error.message).to include('exit code: 2')
        expect(error.stderr).to be_nil
      end

      it 'handles stderr without exit code' do
        error = ClaudeCodeSDK::ProcessError.new('Failed', stderr: 'Error details')
        
        expect(error.message).to include('Error details')
        expect(error.exit_code).to be_nil
      end
    end

    describe ClaudeCodeSDK::CLIJSONDecodeError do
      it 'inherits from ClaudeSDKError' do
        expect(ClaudeCodeSDK::CLIJSONDecodeError.new).to be_a(ClaudeCodeSDK::ClaudeSDKError)
      end

      it 'includes line and original error' do
        original = JSON::ParserError.new("Invalid JSON")
        error = ClaudeCodeSDK::CLIJSONDecodeError.new("invalid json line", original)
        
        expect(error.line).to eq("invalid json line")
        expect(error.original_error).to eq(original)
        expect(error.message).to include("Failed to decode JSON")
      end

      it 'works with just a line' do
        error = ClaudeCodeSDK::CLIJSONDecodeError.new('bad json')
        
        expect(error.line).to eq('bad json')
        expect(error.original_error).to be_nil
        expect(error.message).to include('Failed to decode JSON')
      end

      it 'provides helpful error context' do
        json_line = '{"type": "invalid", missing_quote}'
        original = JSON::ParserError.new('unexpected token')
        error = ClaudeCodeSDK::CLIJSONDecodeError.new(json_line, original)
        
        expect(error.message).to include('Failed to decode JSON')
        expect(error.message).to include(json_line)
        expect(error.message).to include('unexpected token')
      end
    end
  end

  describe 'error handling in real scenarios' do
    let(:mock_client) { instance_double(ClaudeCodeSDK::Client) }

    before do
      allow(ClaudeCodeSDK::Client).to receive(:new).and_return(mock_client)
    end

    it 'propagates CLINotFoundError from client' do
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCodeSDK::CLINotFoundError.new('CLI not found'))
      
      expect do
        ClaudeCodeSDK.query(prompt: 'test').to_a
      end.to raise_error(ClaudeCodeSDK::CLINotFoundError, /CLI not found/)
    end

    it 'propagates ProcessError from client' do
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCodeSDK::ProcessError.new('Process failed', exit_code: 1))
      
      expect do
        ClaudeCodeSDK.query(prompt: 'test').to_a
      end.to raise_error(ClaudeCodeSDK::ProcessError) do |error|
        expect(error.exit_code).to eq(1)
      end
    end

    it 'propagates CLIJSONDecodeError from client' do
      json_error = JSON::ParserError.new('Invalid')
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCodeSDK::CLIJSONDecodeError.new('bad json', json_error))
      
      expect do
        ClaudeCodeSDK.query(prompt: 'test').to_a
      end.to raise_error(ClaudeCodeSDK::CLIJSONDecodeError) do |error|
        expect(error.line).to eq('bad json')
        expect(error.original_error).to eq(json_error)
      end
    end

    it 'handles errors in streaming' do
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCodeSDK::CLIConnectionError.new('Connection lost'))
      
      expect do
        ClaudeCodeSDK.stream_query(prompt: 'test') { |msg| }
      end.to raise_error(ClaudeCodeSDK::CLIConnectionError, /Connection lost/)
    end

    it 'handles errors in JSON streaming' do
      messages = [{ 'type' => 'user', 'message' => { 'role' => 'user', 'content' => [] } }]
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCodeSDK::ProcessError.new('JSON processing failed'))
      
      expect do
        ClaudeCodeSDK.stream_json_query(messages) { |msg| }
      end.to raise_error(ClaudeCodeSDK::ProcessError, /JSON processing failed/)
    end
  end
end