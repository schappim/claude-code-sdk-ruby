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
  end
end