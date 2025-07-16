# frozen_string_literal: true

RSpec.describe ClaudeCodeSDK do
  it 'has a version number' do
    expect(ClaudeCodeSDK::VERSION).not_to be nil
  end

  describe '.query' do
    it 'accepts prompt and options parameters' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(max_turns: 1)
      
      # Mock the client to avoid actually calling claude
      client = instance_double(ClaudeCodeSDK::Client)
      allow(ClaudeCodeSDK::Client).to receive(:new).and_return(client)
      allow(client).to receive(:process_query).and_return([])
      
      expect { ClaudeCodeSDK.query(prompt: "test", options: options) }.not_to raise_error
    end
  end
end