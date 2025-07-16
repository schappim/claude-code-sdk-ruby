# frozen_string_literal: true

RSpec.describe ClaudeCode do
  describe 'message types' do
    describe ClaudeCode::TextBlock do
      it 'initializes with text' do
        block = ClaudeCode::TextBlock.new("Hello")
        expect(block.text).to eq("Hello")
      end
    end

    describe ClaudeCode::ToolUseBlock do
      it 'initializes with required parameters' do
        block = ClaudeCode::ToolUseBlock.new(
          id: "test-id",
          name: "test-tool",
          input: { "key" => "value" }
        )
        
        expect(block.id).to eq("test-id")
        expect(block.name).to eq("test-tool")
        expect(block.input).to eq({ "key" => "value" })
      end
    end

    describe ClaudeCode::UserMessage do
      it 'initializes with content' do
        message = ClaudeCode::UserMessage.new("Hello Claude")
        expect(message.content).to eq("Hello Claude")
      end
    end

    describe ClaudeCode::AssistantMessage do
      it 'initializes with content blocks' do
        blocks = [ClaudeCode::TextBlock.new("Hello")]
        message = ClaudeCode::AssistantMessage.new(blocks)
        expect(message.content).to eq(blocks)
      end
    end
  end

  describe ClaudeCode::ClaudeCodeOptions do
    it 'initializes with default values' do
      options = ClaudeCode::ClaudeCodeOptions.new
      
      expect(options.allowed_tools).to eq([])
      expect(options.max_thinking_tokens).to eq(8000)
      expect(options.system_prompt).to be_nil
      expect(options.continue_conversation).to be false
    end

    it 'accepts custom values' do
      options = ClaudeCode::ClaudeCodeOptions.new(
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
        options = ClaudeCode::ClaudeCodeOptions.new(
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