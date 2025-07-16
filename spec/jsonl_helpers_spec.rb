# frozen_string_literal: true

RSpec.describe ClaudeCode::JSONLHelpers do
  describe '.create_user_message' do
    it 'creates properly formatted user message' do
      text = 'Hello Claude!'
      result = described_class.create_user_message(text)
      
      expect(result).to eq({
        'type' => 'user',
        'message' => {
          'role' => 'user',
          'content' => [
            {
              'type' => 'text',
              'text' => text
            }
          ]
        }
      })
    end

    it 'handles empty text' do
      result = described_class.create_user_message('')
      
      expect(result['message']['content'][0]['text']).to eq('')
    end

    it 'handles multiline text' do
      text = "Line 1\nLine 2\nLine 3"
      result = described_class.create_user_message(text)
      
      expect(result['message']['content'][0]['text']).to eq(text)
    end

    it 'handles special characters' do
      text = 'Text with "quotes" and \'apostrophes\' and unicode: 🚀'
      result = described_class.create_user_message(text)
      
      expect(result['message']['content'][0]['text']).to eq(text)
    end
  end

  describe '.create_conversation' do
    it 'creates multiple user messages from strings' do
      turns = ['Hello', 'How are you?', 'Goodbye']
      result = described_class.create_conversation(*turns)
      
      expect(result.length).to eq(3)
      
      result.each_with_index do |message, index|
        expect(message['type']).to eq('user')
        expect(message['message']['role']).to eq('user')
        expect(message['message']['content'][0]['text']).to eq(turns[index])
      end
    end

    it 'handles single message' do
      result = described_class.create_conversation('Single message')
      
      expect(result.length).to eq(1)
      expect(result[0]['message']['content'][0]['text']).to eq('Single message')
    end

    it 'handles empty array' do
      result = described_class.create_conversation()
      
      expect(result).to eq([])
    end

    it 'filters out nil and empty strings' do
      result = described_class.create_conversation('Valid', nil, '', 'Also valid')
      
      expect(result.length).to eq(2)
      expect(result[0]['message']['content'][0]['text']).to eq('Valid')
      expect(result[1]['message']['content'][0]['text']).to eq('Also valid')
    end
  end

  describe '.format_messages_as_jsonl' do
    let(:messages) do
      [
        described_class.create_user_message('First message'),
        described_class.create_user_message('Second message')
      ]
    end

    it 'formats messages as JSONL string' do
      result = described_class.format_messages_as_jsonl(messages)
      
      lines = result.strip.split("\n")
      expect(lines.length).to eq(2)
      
      # Each line should be valid JSON
      lines.each do |line|
        expect { JSON.parse(line) }.not_to raise_error
      end
      
      # Verify content
      first_parsed = JSON.parse(lines[0])
      expect(first_parsed['message']['content'][0]['text']).to eq('First message')
    end

    it 'handles empty array' do
      result = described_class.format_messages_as_jsonl([])
      
      expect(result.strip).to eq('')
    end

    it 'handles single message' do
      single_message = [described_class.create_user_message('Test')]
      result = described_class.format_messages_as_jsonl(single_message)
      
      lines = result.strip.split("\n")
      expect(lines.length).to eq(1)
      
      parsed = JSON.parse(lines[0])
      expect(parsed['message']['content'][0]['text']).to eq('Test')
    end

    it 'preserves message structure exactly' do
      original_message = {
        'type' => 'user',
        'message' => {
          'role' => 'user',
          'content' => [
            { 'type' => 'text', 'text' => 'Test message' }
          ]
        },
        'custom_field' => 'custom_value'
      }
      
      result = described_class.format_messages_as_jsonl([original_message])
      parsed = JSON.parse(result.strip)
      
      expect(parsed).to eq(original_message)
    end
  end

  describe 'integration with streaming JSON' do
    it 'creates messages compatible with stream_json_query' do
      messages = described_class.create_conversation(
        'Hello Claude',
        'Can you help me?',
        'Thank you'
      )
      
      # These should be the exact format expected by the CLI
      messages.each do |message|
        expect(message).to have_key('type')
        expect(message).to have_key('message')
        expect(message['type']).to eq('user')
        expect(message['message']).to have_key('role')
        expect(message['message']).to have_key('content')
        expect(message['message']['role']).to eq('user')
        expect(message['message']['content']).to be_an(Array)
        expect(message['message']['content'][0]).to have_key('type')
        expect(message['message']['content'][0]).to have_key('text')
      end
    end
  end
end