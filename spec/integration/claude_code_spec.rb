# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClaudeCode, :integration do
  describe 'end-to-end functionality with mocked CLI responses' do
    before do
      stub_cli_found('/usr/local/bin/claude')
    end

    describe 'simple query response' do
      it 'processes a simple text response' do
        responses = [
          test_assistant_message('2 + 2 equals 4'),
          test_result_message(cost: 0.001, duration: 1000)
        ]

        mock_popen3(
          stdout_lines: responses.map(&:to_json),
          exit_status: 0
        )

        messages = []
        ClaudeCode.query('What is 2 + 2?') do |msg|
          messages << msg
        end

        # Verify results
        expect(messages.length).to eq(2)

        # Check assistant message
        expect(messages[0]).to be_a(ClaudeCode::AssistantMessage)
        expect(messages[0].content.length).to eq(1)
        expect(messages[0].content[0].text).to eq('2 + 2 equals 4')

        # Check result message
        expect(messages[1]).to be_a(ClaudeCode::ResultMessage)
        expect(messages[1].total_cost_usd).to eq(0.001)
        expect(messages[1].session_id).to eq('test-session')
      end
    end

    describe 'query with tool use' do
      it 'processes messages with tool usage' do
        responses = [
          test_tool_use_message('Read', { 'file_path' => '/test.txt' }),
          test_result_message(cost: 0.002, duration: 1500)
        ]

        mock_popen3(
          stdout_lines: responses.map(&:to_json),
          exit_status: 0
        )

        options = ClaudeCode::ClaudeCodeOptions.new(allowed_tools: ['Read'])
        messages = []

        ClaudeCode.query('Read /test.txt', options: options) do |msg|
          messages << msg
        end

        # Verify results
        expect(messages.length).to eq(2)

        # Check assistant message with tool use
        assistant_msg = messages[0]
        expect(assistant_msg).to be_a(ClaudeCode::AssistantMessage)
        expect(assistant_msg.content.length).to eq(1)

        tool_use = assistant_msg.content[0]
        expect(tool_use).to be_a(ClaudeCode::ToolUseBlock)
        expect(tool_use.name).to eq('Read')
        expect(tool_use.input['file_path']).to eq('/test.txt')
      end
    end

    describe 'CLI not found' do
      it 'raises appropriate error when CLI is not available' do
        stub_cli_not_found

        expect do
          ClaudeCode.query('test') { |_| nil }
        end.to raise_error(ClaudeCode::CLINotFoundError) do |error|
          expect(error.message).to include('CLI not found')
        end
      end
    end

    describe 'streaming behavior' do
      it 'returns an enumerator when no block is given' do
        responses = [test_assistant_message('Hello from enumerator')]

        mock_popen3(
          stdout_lines: responses.map(&:to_json),
          exit_status: 0
        )

        result = ClaudeCode.query('test')
        expect(result).to be_a(Enumerator)

        messages = result.to_a
        expect(messages.length).to eq(1)
        expect(messages[0].content[0].text).to eq('Hello from enumerator')
      end
    end

    describe 'MCP integration' do
      it 'works with MCP servers configured' do
        mcp_servers = {
          'test_server' => ClaudeCode::McpHttpServerConfig.new(
            url: 'http://test.com'
          )
        }

        options = ClaudeCode::ClaudeCodeOptions.new(
          mcp_servers: mcp_servers,
          allowed_tools: ['mcp__test_server__test_tool']
        )

        responses = [
          test_assistant_message('MCP response'),
          test_result_message
        ]

        mock_popen3(
          stdout_lines: responses.map(&:to_json),
          exit_status: 0
        )

        messages = []
        ClaudeCode.query('Use MCP tool', options: options) do |msg|
          messages << msg
        end

        expect(messages.length).to eq(2)
        expect(messages[0].content[0].text).to eq('MCP response')
      end
    end
  end
end