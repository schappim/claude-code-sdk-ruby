# Ruby Claude Code SDK - Usage Examples

## Directory Structure

```
ruby/
├── lib/claude_code_sdk.rb           # Main SDK entry point
├── docs/                            # Comprehensive documentation
├── examples/                        # Working code examples
├── spec/                           # RSpec tests
└── README.md                       # Quick start guide
```

## Quick Start

### 1. From the ruby directory:

```bash
cd ruby

# Install dependencies
bundle install

# Try basic examples
ruby examples/basic_usage.rb
ruby examples/streaming_examples.rb
ruby examples/mcp_examples.rb
ruby examples/conversation_resuming.rb
ruby examples/authentication_examples.rb
```

### 2. In IRB/console:

```ruby
# Load from ruby directory
require_relative 'lib/claude_code_sdk'

# Or load with helpers
require_relative 'examples/irb_helpers'

# Then use:
quick_claude("What is Ruby?")
stream_claude("Explain blocks")
ninja_test("Tell me about yourself")

# Conversation helpers:
continue_chat("Follow up question")
resume_chat("session-id", "New prompt")
save_session("session-id")
resume_last("Continue with last session")
```

### 3. In a Ruby project:

```ruby
# Add to your project
require_relative 'path/to/ruby/lib/claude_code_sdk'

# Use normally
ClaudeCodeSDK.query(prompt: "Hello").each { |msg| puts msg }
```

## Rails + Sidekiq Streaming Example

Here's how to integrate the SDK with Rails and Sidekiq for real-time streaming:

### 1. Gemfile

```ruby
# Gemfile
gem 'sidekiq'
gem 'redis'

# Add the Claude SDK (assuming it's in your project)
# gem 'claude_code_sdk', path: 'vendor/claude-code-sdk-ruby'
```

### 2. Sidekiq Job

```ruby
# app/jobs/claude_streaming_job.rb
class ClaudeStreamingJob
  include Sidekiq::Job
  
  def perform(user_id, query_id, prompt, options = {})
    require_relative '../vendor/claude-code-sdk-ruby/lib/claude_code_sdk'
    
    channel = "claude_stream_#{user_id}_#{query_id}"
    
    # Parse options
    claude_options = ClaudeCodeSDK::ClaudeCodeOptions.new(
      model: options['model'],
      max_turns: options['max_turns'] || 1,
      system_prompt: options['system_prompt'],
      allowed_tools: options['allowed_tools'] || []
    )
    
    # Stream Claude responses
    message_count = 0
    ClaudeCodeSDK.query(
      prompt: prompt,
      options: claude_options,
      cli_path: ENV['CLAUDE_CLI_PATH'] || '/usr/local/bin/claude'
    ).each do |message|
      message_count += 1
      
      # Broadcast each message via ActionCable
      ActionCable.server.broadcast(channel, {
        type: 'claude_message',
        query_id: query_id,
        message_index: message_count,
        timestamp: Time.current.iso8601,
        data: serialize_claude_message(message)
      })
      
      # Optional: Save to database
      save_message_to_db(user_id, query_id, message_count, message)
    end
    
    # Broadcast completion
    ActionCable.server.broadcast(channel, {
      type: 'complete',
      query_id: query_id,
      total_messages: message_count,
      timestamp: Time.current.iso8601
    })
  end
  
  private
  
  def serialize_claude_message(message)
    case message
    when ClaudeCodeSDK::SystemMessage
      {
        message_type: 'system',
        subtype: message.subtype,
        data: message.data
      }
    when ClaudeCodeSDK::AssistantMessage
      {
        message_type: 'assistant',
        content: message.content.map { |block| serialize_content_block(block) }
      }
    when ClaudeCodeSDK::ResultMessage
      {
        message_type: 'result',
        subtype: message.subtype,
        duration_ms: message.duration_ms,
        cost_usd: message.total_cost_usd,
        session_id: message.session_id
      }
    end
  end
  
  def serialize_content_block(block)
    case block
    when ClaudeCodeSDK::TextBlock
      { type: 'text', text: block.text }
    when ClaudeCodeSDK::ToolUseBlock
      { type: 'tool_use', id: block.id, name: block.name, input: block.input }
    when ClaudeCodeSDK::ToolResultBlock
      { type: 'tool_result', tool_use_id: block.tool_use_id, content: block.content, is_error: block.is_error }
    end
  end
  
  def save_message_to_db(user_id, query_id, message_index, message)
    # Example database save
    # ClaudeMessage.create!(
    #   user_id: user_id,
    #   query_id: query_id,
    #   message_index: message_index,
    #   message_data: serialize_claude_message(message),
    #   created_at: Time.current
    # )
  end
end
```

### 3. ActionCable Channel

```ruby
# app/channels/claude_stream_channel.rb
class ClaudeStreamChannel < ApplicationCable::Channel
  def subscribed
    # Authorize user access
    if params[:user_id].to_i == current_user.id
      stream_from "claude_stream_#{params[:user_id]}_#{params[:query_id]}"
    else
      reject
    end
  end
  
  def unsubscribed
    # Cleanup when channel is unsubscribed
  end
end
```

### 4. Controller

```ruby
# app/controllers/claude_controller.rb
class ClaudeController < ApplicationController
  before_action :authenticate_user!
  
  def create_stream_query
    query_id = SecureRandom.uuid
    
    # Validate input
    prompt = params.require(:prompt)
    options = {
      'model' => params[:model],
      'max_turns' => params[:max_turns]&.to_i,
      'system_prompt' => params[:system_prompt],
      'allowed_tools' => params[:allowed_tools] || []
    }
    
    # Start background job
    ClaudeStreamingJob.perform_async(
      current_user.id,
      query_id,
      prompt,
      options
    )
    
    render json: {
      query_id: query_id,
      channel: "claude_stream_#{current_user.id}_#{query_id}",
      status: 'started'
    }
  end
end
```

### 5. Frontend JavaScript

```javascript
// app/javascript/claude_streaming.js
class ClaudeStreaming {
  constructor(userId) {
    this.userId = userId;
    this.activeSubscriptions = new Map();
  }
  
  startQuery(prompt, options = {}) {
    return fetch('/claude/stream_query', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        prompt: prompt,
        model: options.model,
        max_turns: options.maxTurns,
        system_prompt: options.systemPrompt,
        allowed_tools: options.allowedTools
      })
    })
    .then(response => response.json())
    .then(data => {
      this.subscribeToQuery(data.query_id, options.onMessage, options.onComplete);
      return data;
    });
  }
  
  subscribeToQuery(queryId, onMessage, onComplete) {
    const subscription = App.cable.subscriptions.create(
      {
        channel: "ClaudeStreamChannel",
        user_id: this.userId,
        query_id: queryId
      },
      {
        received: (data) => {
          switch(data.type) {
            case 'claude_message':
              this.handleClaudeMessage(data, onMessage);
              break;
            case 'complete':
              this.handleComplete(data, onComplete);
              this.unsubscribeFromQuery(queryId);
              break;
          }
        }
      }
    );
    
    this.activeSubscriptions.set(queryId, subscription);
  }
  
  handleClaudeMessage(data, onMessage) {
    const message = data.data;
    
    if (message.message_type === 'assistant') {
      message.content.forEach(block => {
        if (block.type === 'text') {
          onMessage({
            type: 'text',
            content: block.text,
            timestamp: data.timestamp
          });
        } else if (block.type === 'tool_use') {
          onMessage({
            type: 'tool_use',
            tool: block.name,
            input: block.input,
            timestamp: data.timestamp
          });
        }
      });
    } else if (message.message_type === 'result') {
      onMessage({
        type: 'result',
        cost: message.cost_usd,
        duration: message.duration_ms,
        timestamp: data.timestamp
      });
    }
  }
  
  handleComplete(data, onComplete) {
    if (onComplete) {
      onComplete({
        queryId: data.query_id,
        totalMessages: data.total_messages,
        timestamp: data.timestamp
      });
    }
  }
  
  unsubscribeFromQuery(queryId) {
    const subscription = this.activeSubscriptions.get(queryId);
    if (subscription) {
      subscription.unsubscribe();
      this.activeSubscriptions.delete(queryId);
    }
  }
}

// Usage
const claudeStreaming = new ClaudeStreaming(currentUserId);

claudeStreaming.startQuery("Explain Ruby on Rails", {
  model: "sonnet",
  maxTurns: 1,
  onMessage: (message) => {
    console.log('Received:', message);
    if (message.type === 'text') {
      appendToChat(message.content);
    } else if (message.type === 'tool_use') {
      showToolUsage(message.tool, message.input);
    }
  },
  onComplete: (summary) => {
    console.log('Query completed:', summary);
    showCompletionMessage(summary);
  }
});
```

### 6. Environment Configuration

```bash
# .env
CLAUDE_CLI_PATH=/usr/local/bin/claude
ANTHROPIC_API_KEY=your_api_key_here
REDIS_URL=redis://localhost:6379/0
```

### 7. Rails Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount ActionCable.server => '/cable'
  
  resources :claude, only: [] do
    collection do
      post 'stream_query'
    end
  end
end
```

## Usage in Rails Console

```ruby
# Start a streaming query
ClaudeStreamingJob.perform_async(
  1,                                    # user_id
  SecureRandom.uuid,                   # query_id
  "Explain Ruby metaprogramming",     # prompt
  {
    'model' => 'sonnet',
    'max_turns' => 1,
    'system_prompt' => 'You are a Ruby expert'
  }
)

# With MCP servers
ClaudeStreamingJob.perform_async(
  1,
  SecureRandom.uuid,
  "Use the about tool",
  {
    'model' => 'sonnet',
    'allowed_tools' => ['mcp__ninja__about'],
    'mcp_servers' => {
      'ninja' => 'https://mcp-creator-ninja-v1-4-0.mcp.soy/'
    }
  }
)
```

This setup provides:
- ✅ Real-time streaming via WebSockets
- ✅ Background processing with Sidekiq
- ✅ Error handling and retry logic  
- ✅ Message persistence (optional)
- ✅ User authentication and authorization
- ✅ Frontend integration with ActionCable
- ✅ MCP server support
- ✅ Cost tracking and monitoring

The streaming happens in real-time, so users see Claude's responses as they're generated, providing an excellent user experience for AI-powered Rails applications.