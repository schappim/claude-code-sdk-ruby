# frozen_string_literal: true

RSpec.describe ClaudeCodeSDK do
  describe 'message types' do
    describe ClaudeCodeSDK::TextBlock do
      it 'initializes with text' do
        block = ClaudeCodeSDK::TextBlock.new("Hello")
        expect(block.text).to eq("Hello")
      end
    end

    describe ClaudeCodeSDK::ToolUseBlock do
      it 'initializes with required parameters' do
        block = ClaudeCodeSDK::ToolUseBlock.new(
          id: "test-id",
          name: "test-tool",
          input: { "key" => "value" }
        )
        
        expect(block.id).to eq("test-id")
        expect(block.name).to eq("test-tool")
        expect(block.input).to eq({ "key" => "value" })
      end
    end

    describe ClaudeCodeSDK::UserMessage do
      it 'initializes with content' do
        message = ClaudeCodeSDK::UserMessage.new("Hello Claude")
        expect(message.content).to eq("Hello Claude")
      end
    end

    describe ClaudeCodeSDK::AssistantMessage do
      it 'initializes with content blocks' do
        blocks = [ClaudeCodeSDK::TextBlock.new("Hello")]
        message = ClaudeCodeSDK::AssistantMessage.new(blocks)
        expect(message.content).to eq(blocks)
      end
    end
  end

  describe ClaudeCodeSDK::ClaudeCodeOptions do
    it 'initializes with default values' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new
      
      expect(options.allowed_tools).to eq([])
      expect(options.max_thinking_tokens).to eq(8000)
      expect(options.system_prompt).to be_nil
      expect(options.continue_conversation).to be false
    end

    it 'accepts custom values' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(
        allowed_tools: ["Read", "Write"],
        system_prompt: "Test prompt",
        max_turns: 5
      )
      
      expect(options.allowed_tools).to eq(["Read", "Write"])
      expect(options.system_prompt).to eq("Test prompt")
      expect(options.max_turns).to eq(5)
    end

    describe '#to_h' do
      it 'converts to hash with compact values' do
        options = ClaudeCodeSDK::ClaudeCodeOptions.new(
          system_prompt: "Test",
          max_turns: 1
        )
        
        hash = options.to_h
        expect(hash[:system_prompt]).to eq("Test")
        expect(hash[:max_turns]).to eq(1)
        expect(hash.key?(:append_system_prompt)).to be false
      end
    end
  end
end