# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClaudeCodeSDK::Client do
  let(:client) { described_class.new }
  let(:options) { ClaudeCodeSDK::ClaudeCodeOptions.new }

  describe '#process_query' do
    context 'with successful CLI execution' do
      it 'returns streaming messages' do
        stub_cli_found('/usr/local/bin/claude')

        responses = [
          test_assistant_message('Hello, world!'),
          test_result_message
        ]

        mock_popen3(
          stdout_lines: responses.map(&:to_json),
          exit_status: 0
        )

        messages = []
        enumerator = client.process_query(prompt: 'Hello', options: options)

        enumerator.each do |message|
          messages << message
        end

        expect(messages.length).to eq(2)
        expect(messages[0]).to be_a(ClaudeCodeSDK::AssistantMessage)
        expect(messages[1]).to be_a(ClaudeCodeSDK::ResultMessage)
      end

      it 'handles streaming JSON input' do
        stub_cli_found('/usr/local/bin/claude')
        
        messages = [
          { 'type' => 'user', 'message' => { 'role' => 'user', 'content' => [{ 'type' => 'text', 'text' => 'Hello' }] } }
        ]
        
        options_with_stream = ClaudeCodeSDK::ClaudeCodeOptions.new(input_format: 'stream-json')
        
        # For streaming JSON, we need special handling of stdin
        stdin_r, stdin_w = IO.pipe
        stdout_r, stdout_w = IO.pipe
        stderr_r, stderr_w = IO.pipe
        
        # Write responses
        responses = [test_assistant_message('Response'), test_result_message]
        responses.each { |r| stdout_w.puts(r.to_json) }
        stdout_w.close
        stderr_w.close
        
        # Mock process that accepts stdin writes
        process = instance_double(Process::Waiter)
        allow(process).to receive_messages(
          pid: 12345,
          alive?: true,
          value: instance_double(Process::Status, exitstatus: 0),
          join: nil
        )
        
        allow(Open3).to receive(:popen3).and_return([stdin_w, stdout_r, stderr_r, process])
        
        # Don't try to read the messages since stdin is mocked
        allow_any_instance_of(ClaudeCodeSDK::SubprocessCLITransport).to receive(:send_messages) do |transport, msgs|
          # Close stdin to signal end of input
          stdin_w.close
        end
        
        result = client.process_query(messages: messages, options: options_with_stream)
        
        expect(result.to_a.length).to eq(2)
      end

      it 'handles system messages' do
        stub_cli_found('/usr/local/bin/claude')
        
        responses = [
          test_system_message(subtype: 'init'),
          test_assistant_message('Hello'),
          test_result_message
        ]
        
        mock_popen3(stdout_lines: responses.map(&:to_json), exit_status: 0)
        
        messages = client.process_query(prompt: 'Hello', options: options).to_a
        
        expect(messages.length).to eq(3)
        expect(messages[0]).to be_a(ClaudeCodeSDK::SystemMessage)
        expect(messages[1]).to be_a(ClaudeCodeSDK::AssistantMessage)
        expect(messages[2]).to be_a(ClaudeCodeSDK::ResultMessage)
      end

      it 'handles mixed content types' do
        stub_cli_found('/usr/local/bin/claude')
        
        mixed_content_message = {
          'type' => 'assistant',
          'message' => {
            'role' => 'assistant',
            'content' => [
              { 'type' => 'text', 'text' => 'I will read the file' },
              { 'type' => 'tool_use', 'id' => 'tool-1', 'name' => 'Read', 'input' => { 'file_path' => '/test.txt' } },
              { 'type' => 'tool_result', 'tool_use_id' => 'tool-1', 'content' => 'File contents', 'is_error' => false }
            ]
          }
        }
        
        mock_popen3(stdout_lines: [mixed_content_message.to_json], exit_status: 0)
        
        messages = client.process_query(prompt: 'Read file', options: options).to_a
        
        expect(messages.length).to eq(1)
        message = messages[0]
        expect(message.content.length).to eq(3)
        expect(message.content[0]).to be_a(ClaudeCodeSDK::TextBlock)
        expect(message.content[1]).to be_a(ClaudeCodeSDK::ToolUseBlock)
        expect(message.content[2]).to be_a(ClaudeCodeSDK::ToolResultBlock)
      end
    end

    context 'with CLI connection failure' do
      it 'raises CLIConnectionError' do
        stub_cli_found('/usr/local/bin/claude')
        
        allow_any_instance_of(ClaudeCodeSDK::SubprocessCLITransport)
          .to receive(:connect).and_raise(ClaudeCodeSDK::CLIConnectionError.new('Connection failed'))

        expect do
          client.process_query(prompt: 'Hello', options: options).to_a
        end.to raise_error(ClaudeCodeSDK::CLIConnectionError, /Connection failed/)
      end
    end

    context 'with CLI not found' do
      it 'raises CLINotFoundError' do
        stub_cli_not_found
        
        expect do
          client.process_query(prompt: 'Hello', options: options).to_a
        end.to raise_error(ClaudeCodeSDK::CLINotFoundError)
      end
    end

    context 'with process failure' do
      it 'raises ProcessError for non-zero exit' do
        stub_cli_found('/usr/local/bin/claude')
        
        mock_popen3(
          stdout_lines: [],
          stderr_lines: ['Error: Something went wrong'],
          exit_status: 1
        )
        
        expect do
          client.process_query(prompt: 'Hello', options: options).to_a
        end.to raise_error(ClaudeCodeSDK::ProcessError) do |error|
          expect(error.exit_code).to eq(1)
          expect(error.stderr).to include('Error: Something went wrong')
        end
      end
    end

    context 'with invalid JSON from CLI' do
      it 'raises CLIJSONDecodeError' do
        stub_cli_found('/usr/local/bin/claude')

        mock_popen3(
          stdout_lines: ['{"invalid": json}'],
          exit_status: 0
        )

        expect do
          client.process_query(prompt: 'Hello', options: options).to_a
        end.to raise_error(ClaudeCodeSDK::CLIJSONDecodeError)
      end

      it 'handles partial JSON lines gracefully' do
        stub_cli_found('/usr/local/bin/claude')
        
        mock_popen3(
          stdout_lines: ['{"type": "partial'], # Incomplete JSON
          exit_status: 0
        )
        
        expect do
          client.process_query(prompt: 'Hello', options: options).to_a
        end.to raise_error(ClaudeCodeSDK::CLIJSONDecodeError)
      end

      it 'skips empty lines' do
        stub_cli_found('/usr/local/bin/claude')
        
        responses = [
          test_assistant_message('Hello').to_json,
          test_result_message.to_json
        ]
        
        mock_popen3(stdout_lines: ['', responses[0], '', responses[1], ''], exit_status: 0)
        
        messages = client.process_query(prompt: 'Hello', options: options).to_a
        
        expect(messages.length).to eq(2)
      end
    end
  end

  describe '#build_environment' do
    it 'includes SDK entrypoint' do
      env = client.send(:build_environment)
      
      expect(env['CLAUDE_CODE_ENTRYPOINT']).to eq('sdk-ruby')
    end

    it 'passes through ANTHROPIC_API_KEY when set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test-key')
      
      env = client.send(:build_environment)
      
      expect(env['ANTHROPIC_API_KEY']).to eq('test-key')
    end

    it 'passes through Bedrock configuration' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CLAUDE_CODE_USE_BEDROCK').and_return('1')
      
      env = client.send(:build_environment)
      
      expect(env['CLAUDE_CODE_USE_BEDROCK']).to eq('1')
    end

    it 'passes through Vertex AI configuration' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CLAUDE_CODE_USE_VERTEX').and_return('1')
      
      env = client.send(:build_environment)
      
      expect(env['CLAUDE_CODE_USE_VERTEX']).to eq('1')
    end
  end

  describe '#parse_message' do
    context 'with assistant message' do
      it 'parses text content correctly' do
        data = test_assistant_message('Hello, world!')
        message = client.send(:parse_message, data)

        expect(message).to be_a(ClaudeCodeSDK::AssistantMessage)
        expect(message.content.length).to eq(1)
        expect(message.content[0].text).to eq('Hello, world!')
      end

      it 'parses tool use content correctly' do
        data = test_tool_use_message('Read', { 'file_path' => '/test.txt' })
        message = client.send(:parse_message, data)

        expect(message).to be_a(ClaudeCodeSDK::AssistantMessage)
        expect(message.content.length).to eq(1)
        
        tool_use = message.content[0]
        expect(tool_use).to be_a(ClaudeCodeSDK::ToolUseBlock)
        expect(tool_use.name).to eq('Read')
        expect(tool_use.input['file_path']).to eq('/test.txt')
      end
    end

    context 'with system message' do
      it 'parses system messages correctly' do
        data = test_system_message(subtype: 'init')
        message = client.send(:parse_message, data)

        expect(message).to be_a(ClaudeCodeSDK::SystemMessage)
        expect(message.subtype).to eq('init')
      end
    end

    context 'with result message' do
      it 'parses result messages correctly' do
        data = test_result_message(cost: 0.005, duration: 2000)
        message = client.send(:parse_message, data)

        expect(message).to be_a(ClaudeCodeSDK::ResultMessage)
        expect(message.total_cost_usd).to eq(0.005)
        expect(message.duration_ms).to eq(2000)
      end
    end

    context 'with unknown message type' do
      it 'returns nil for unknown message types' do
        data = { 'type' => 'unknown', 'data' => 'test' }
        message = client.send(:parse_message, data)

        expect(message).to be_nil
      end
    end

    context 'with malformed content' do
      it 'handles missing content gracefully' do
        data = {
          'type' => 'assistant',
          'message' => {
            'role' => 'assistant'
            # Missing 'content' field
          }
        }
        
        message = client.send(:parse_message, data)
        
        expect(message).to be_a(ClaudeCodeSDK::AssistantMessage)
        expect(message.content).to eq([])
      end

      it 'handles unknown content block types' do
        data = {
          'type' => 'assistant',
          'message' => {
            'role' => 'assistant',
            'content' => [
              { 'type' => 'unknown_type', 'data' => 'test' }
            ]
          }
        }
        
        message = client.send(:parse_message, data)
        
        expect(message).to be_a(ClaudeCodeSDK::AssistantMessage)
        expect(message.content).to eq([])
      end
    end

    context 'with tool result blocks' do
      it 'parses tool result correctly' do
        data = {
          'type' => 'assistant',
          'message' => {
            'role' => 'assistant',
            'content' => [
              {
                'type' => 'tool_result',
                'tool_use_id' => 'tool-123',
                'content' => 'Result content',
                'is_error' => false
              }
            ]
          }
        }
        
        message = client.send(:parse_message, data)
        
        expect(message).to be_a(ClaudeCodeSDK::AssistantMessage)
        tool_result = message.content[0]
        expect(tool_result).to be_a(ClaudeCodeSDK::ToolResultBlock)
        expect(tool_result.tool_use_id).to eq('tool-123')
        expect(tool_result.content).to eq('Result content')
        expect(tool_result.is_error).to be false
      end

      it 'handles error tool results' do
        data = {
          'type' => 'assistant',
          'message' => {
            'role' => 'assistant',
            'content' => [
              {
                'type' => 'tool_result',
                'tool_use_id' => 'tool-123',
                'content' => 'Error message',
                'is_error' => true
              }
            ]
          }
        }
        
        message = client.send(:parse_message, data)
        tool_result = message.content[0]
        
        expect(tool_result.is_error).to be true
        expect(tool_result.content).to eq('Error message')
      end
    end
  end
end