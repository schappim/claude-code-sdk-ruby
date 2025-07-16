# frozen_string_literal: true

RSpec.describe ClaudeCode do
  describe 'error types' do
    describe ClaudeCode::ClaudeSDKError do
      it 'is a standard error' do
        expect(ClaudeCode::ClaudeSDKError.new).to be_a(StandardError)
      end

      it 'accepts custom message' do
        error = ClaudeCode::ClaudeSDKError.new('Custom error message')
        expect(error.message).to eq('Custom error message')
      end
    end

    describe ClaudeCode::CLINotFoundError do
      it 'inherits from CLIConnectionError' do
        expect(ClaudeCode::CLINotFoundError.new).to be_a(ClaudeCode::CLIConnectionError)
      end

      it 'formats message with cli_path when provided' do
        error = ClaudeCode::CLINotFoundError.new("Not found", cli_path: "/usr/bin/claude")
        expect(error.message).to eq("Not found: /usr/bin/claude")
      end

      it 'provides helpful default message' do
        error = ClaudeCode::CLINotFoundError.new
        expect(error.message).to include('Claude Code not found')
      end

      it 'stores cli_path attribute' do
        error = ClaudeCode::CLINotFoundError.new('Test', cli_path: '/test/path')
        expect(error.cli_path).to eq('/test/path')
      end
    end

    describe ClaudeCode::CLIConnectionError do
      it 'inherits from ClaudeSDKError' do
        expect(ClaudeCode::CLIConnectionError.new).to be_a(ClaudeCode::ClaudeSDKError)
      end

      it 'accepts custom message' do
        error = ClaudeCode::CLIConnectionError.new('Connection failed')
        expect(error.message).to eq('Connection failed')
      end
    end

    describe ClaudeCode::ProcessError do
      it 'inherits from ClaudeSDKError' do
        expect(ClaudeCode::ProcessError.new).to be_a(ClaudeCode::ClaudeSDKError)
      end

      it 'includes exit code and stderr in message' do
        error = ClaudeCode::ProcessError.new(
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
        error = ClaudeCode::ProcessError.new('Process failed')
        
        expect(error.message).to eq('Process failed')
        expect(error.exit_code).to be_nil
        expect(error.stderr).to be_nil
      end

      it 'handles exit code without stderr' do
        error = ClaudeCode::ProcessError.new('Failed', exit_code: 2)
        
        expect(error.message).to include('exit code: 2')
        expect(error.stderr).to be_nil
      end

      it 'handles stderr without exit code' do
        error = ClaudeCode::ProcessError.new('Failed', stderr: 'Error details')
        
        expect(error.message).to include('Error details')
        expect(error.exit_code).to be_nil
      end
    end

    describe ClaudeCode::CLIJSONDecodeError do
      it 'inherits from ClaudeSDKError' do
        expect(ClaudeCode::CLIJSONDecodeError.new).to be_a(ClaudeCode::ClaudeSDKError)
      end

      it 'includes line and original error' do
        original = JSON::ParserError.new("Invalid JSON")
        error = ClaudeCode::CLIJSONDecodeError.new("invalid json line", original)
        
        expect(error.line).to eq("invalid json line")
        expect(error.original_error).to eq(original)
        expect(error.message).to include("Failed to decode JSON")
      end

      it 'works with just a line' do
        error = ClaudeCode::CLIJSONDecodeError.new('bad json')
        
        expect(error.line).to eq('bad json')
        expect(error.original_error).to be_nil
        expect(error.message).to include('Failed to decode JSON')
      end

      it 'provides helpful error context' do
        json_line = '{"type": "invalid", missing_quote}'
        original = JSON::ParserError.new('unexpected token')
        error = ClaudeCode::CLIJSONDecodeError.new(json_line, original)
        
        expect(error.message).to include('Failed to decode JSON')
        expect(error.message).to include(json_line)
        expect(error.message).to include('unexpected token')
      end
    end
  end

  describe 'error handling in real scenarios' do
    let(:mock_client) { instance_double(ClaudeCode::Client) }

    before do
      allow(ClaudeCode::Client).to receive(:new).and_return(mock_client)
    end

    it 'propagates CLINotFoundError from client' do
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCode::CLINotFoundError.new('CLI not found'))
      
      expect do
        ClaudeCode.query(prompt: 'test').to_a
      end.to raise_error(ClaudeCode::CLINotFoundError, /CLI not found/)
    end

    it 'propagates ProcessError from client' do
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCode::ProcessError.new('Process failed', exit_code: 1))
      
      expect do
        ClaudeCode.query(prompt: 'test').to_a
      end.to raise_error(ClaudeCode::ProcessError) do |error|
        expect(error.exit_code).to eq(1)
      end
    end

    it 'propagates CLIJSONDecodeError from client' do
      json_error = JSON::ParserError.new('Invalid')
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCode::CLIJSONDecodeError.new('bad json', json_error))
      
      expect do
        ClaudeCode.query(prompt: 'test').to_a
      end.to raise_error(ClaudeCode::CLIJSONDecodeError) do |error|
        expect(error.line).to eq('bad json')
        expect(error.original_error).to eq(json_error)
      end
    end

    it 'handles errors in streaming' do
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCode::CLIConnectionError.new('Connection lost'))
      
      expect do
        ClaudeCode.stream_query(prompt: 'test') { |msg| }
      end.to raise_error(ClaudeCode::CLIConnectionError, /Connection lost/)
    end

    it 'handles errors in JSON streaming' do
      messages = [{ 'type' => 'user', 'message' => { 'role' => 'user', 'content' => [] } }]
      allow(mock_client).to receive(:process_query)
        .and_raise(ClaudeCode::ProcessError.new('JSON processing failed'))
      
      expect do
        ClaudeCode.stream_json_query(messages) { |msg| }
      end.to raise_error(ClaudeCode::ProcessError, /JSON processing failed/)
    end
  end
end