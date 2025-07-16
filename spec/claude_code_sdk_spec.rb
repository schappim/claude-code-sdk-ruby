# frozen_string_literal: true

RSpec.describe ClaudeCodeSDK do
  let(:mock_client) { instance_double(ClaudeCodeSDK::Client) }
  let(:test_messages) do
    [
      test_assistant_message('Hello!'),
      test_result_message
    ]
  end

  before do
    allow(ClaudeCodeSDK::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:process_query).and_return(test_messages.to_enum)
  end

  it 'has a version number' do
    expect(ClaudeCodeSDK::VERSION).not_to be nil
  end

  describe '.query' do
    it 'accepts prompt and options parameters' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(max_turns: 1)
      
      expect { ClaudeCodeSDK.query(prompt: "test", options: options) }.not_to raise_error
    end

    it 'returns an enumerator of messages' do
      result = ClaudeCodeSDK.query(prompt: "Hello Claude")
      
      expect(result).to be_a(Enumerator)
      messages = result.to_a
      expect(messages.length).to eq(2)
    end

    it 'passes prompt to client correctly' do
      prompt = "What is Ruby?"
      ClaudeCodeSDK.query(prompt: prompt)
      
      expect(mock_client).to have_received(:process_query)
        .with(hash_including(prompt: prompt))
    end

    it 'passes options to client correctly' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(max_turns: 3, model: 'claude-3-haiku')
      ClaudeCodeSDK.query(prompt: "test", options: options)
      
      expect(mock_client).to have_received(:process_query)
        .with(hash_including(options: options))
    end

    it 'passes CLI path when provided' do
      cli_path = '/custom/path/to/claude'
      ClaudeCodeSDK.query(prompt: "test", cli_path: cli_path)
      
      expect(mock_client).to have_received(:process_query)
        .with(hash_including(cli_path: cli_path))
    end

    it 'passes MCP servers when provided' do
      mcp_servers = { 'test' => 'http://example.com' }
      ClaudeCodeSDK.query(prompt: "test", mcp_servers: mcp_servers)
      
      expect(mock_client).to have_received(:process_query)
        .with(hash_including(mcp_servers: mcp_servers))
    end
  end

  describe '.continue_conversation' do
    it 'calls query with continue_conversation flag' do
      expect(ClaudeCodeSDK).to receive(:query).with(
        prompt: 'Follow up',
        options: instance_of(ClaudeCodeSDK::ClaudeCodeOptions),
        cli_path: nil,
        mcp_servers: {}
      )
      
      ClaudeCodeSDK.continue_conversation('Follow up')
    end

    it 'sets continue_conversation to true in options' do
      allow(ClaudeCodeSDK).to receive(:query)
      
      ClaudeCodeSDK.continue_conversation('test')
      
      expect(ClaudeCodeSDK).to have_received(:query) do |**kwargs|
        expect(kwargs[:options].continue_conversation).to be true
      end
    end

    it 'merges with existing options' do
      existing_options = ClaudeCodeSDK::ClaudeCodeOptions.new(max_turns: 5)
      allow(ClaudeCodeSDK).to receive(:query)
      
      ClaudeCodeSDK.continue_conversation('test', options: existing_options)
      
      expect(ClaudeCodeSDK).to have_received(:query) do |**kwargs|
        options = kwargs[:options]
        expect(options.continue_conversation).to be true
        expect(options.max_turns).to eq(5)
      end
    end

    it 'works without prompt (resume only)' do
      expect { ClaudeCodeSDK.continue_conversation(nil) }.not_to raise_error
    end
  end

  describe '.resume_conversation' do
    let(:session_id) { 'test-session-123' }

    it 'calls query with resume flags' do
      expect(ClaudeCodeSDK).to receive(:query).with(
        prompt: 'Resume prompt',
        options: instance_of(ClaudeCodeSDK::ClaudeCodeOptions),
        cli_path: nil,
        mcp_servers: {}
      )
      
      ClaudeCodeSDK.resume_conversation(session_id, 'Resume prompt')
    end

    it 'sets resume_conversation_id in options' do
      allow(ClaudeCodeSDK).to receive(:query)
      
      ClaudeCodeSDK.resume_conversation(session_id, 'test')
      
      expect(ClaudeCodeSDK).to have_received(:query) do |**kwargs|
        expect(kwargs[:options].resume_conversation_id).to eq(session_id)
      end
    end

    it 'works without prompt' do
      expect { ClaudeCodeSDK.resume_conversation(session_id) }.not_to raise_error
    end
  end

  describe '.stream_query' do
    it 'yields messages to block when provided' do
      yielded_messages = []
      
      ClaudeCodeSDK.stream_query(prompt: "test") do |message, index|
        yielded_messages << [message, index]
      end
      
      expect(yielded_messages.length).to eq(2)
      expect(yielded_messages[0][1]).to eq(0)
      expect(yielded_messages[1][1]).to eq(1)
    end

    it 'auto-formats when no block given' do
      # Mock the auto-formatting behavior
      expect(ClaudeCodeSDK).to receive(:auto_format_message).twice
      
      ClaudeCodeSDK.stream_query(prompt: "test")
    end
  end

  describe '.stream_json_query' do
    let(:jsonl_messages) do
      [
        { 'type' => 'user', 'message' => { 'role' => 'user', 'content' => [{ 'type' => 'text', 'text' => 'Hello' }] } }
      ]
    end

    it 'sets input_format to stream-json in options' do
      ClaudeCodeSDK.stream_json_query(jsonl_messages)
      
      expect(mock_client).to have_received(:process_query) do |**kwargs|
        expect(kwargs[:options].input_format).to eq('stream-json')
      end
    end

    it 'passes messages to client correctly' do
      ClaudeCodeSDK.stream_json_query(jsonl_messages)
      
      expect(mock_client).to have_received(:process_query) do |**kwargs|
        expect(kwargs[:messages]).to eq(jsonl_messages)
      end
    end

    it 'yields to block when provided' do
      yielded_messages = []
      
      ClaudeCodeSDK.stream_json_query(jsonl_messages) do |message|
        yielded_messages << message
      end
      
      expect(yielded_messages.length).to eq(2)
    end
  end

  describe '.add_mcp_server' do
    it 'returns correct MCP configuration hash' do
      result = ClaudeCodeSDK.add_mcp_server('test', 'http://example.com')
      
      expect(result).to eq({ 'test' => 'http://example.com' })
    end

    it 'handles complex configurations' do
      config = { url: 'http://example.com', tools: ['tool1'] }
      result = ClaudeCodeSDK.add_mcp_server('test', config)
      
      expect(result).to eq({ 'test' => config })
    end
  end

  describe '.quick_mcp_query' do
    it 'creates proper MCP configuration and calls query' do
      expect(ClaudeCodeSDK).to receive(:query).with(
        prompt: 'test prompt',
        options: instance_of(ClaudeCodeSDK::ClaudeCodeOptions),
        mcp_servers: { 'test_server' => 'http://example.com' },
        cli_path: nil
      )
      
      ClaudeCodeSDK.quick_mcp_query(
        'test prompt',
        server_name: 'test_server',
        server_url: 'http://example.com',
        tools: 'tool1'
      )
    end

    it 'handles array of tools' do
      allow(ClaudeCodeSDK).to receive(:query)
      
      ClaudeCodeSDK.quick_mcp_query(
        'test',
        server_name: 'test',
        server_url: 'http://example.com',
        tools: ['tool1', 'tool2']
      )
      
      expect(ClaudeCodeSDK).to have_received(:query) do |**kwargs|
        expect(kwargs[:options].allowed_tools).to include('mcp__test__tool1', 'mcp__test__tool2')
      end
    end
  end

  describe 'auto-formatting methods' do
    describe '.auto_format_message' do
      it 'formats assistant messages correctly' do
        message = ClaudeCodeSDK::AssistantMessage.new([
          ClaudeCodeSDK::TextBlock.new('Hello world')
        ])
        
        expect { ClaudeCodeSDK.auto_format_message(message) }.to output(/💬 Hello world/).to_stdout
      end

      it 'formats result messages correctly' do
        message = ClaudeCodeSDK::ResultMessage.new(
          subtype: 'success',
          duration_ms: 1000,
          duration_api_ms: 800,
          total_cost_usd: 0.001234,
          num_turns: 1,
          session_id: 'test'
        )
        
        expect { ClaudeCodeSDK.auto_format_message(message) }.to output(/✅.*\$0\.001234/).to_stdout
      end

      it 'handles tool use blocks' do
        message = ClaudeCodeSDK::AssistantMessage.new([
          ClaudeCodeSDK::ToolUseBlock.new(
            id: 'tool-1',
            name: 'Read',
            input: { 'file_path' => '/test.txt' }
          )
        ])
        
        expect { ClaudeCodeSDK.auto_format_message(message) }.to output(/🔧 Read/).to_stdout
      end
    end
  end
end