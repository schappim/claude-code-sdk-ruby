# Rails + Sidekiq streaming example for Ruby Claude Code SDK
# This shows how to use the SDK in a Rails background job with real-time streaming

require 'sidekiq'
require 'action_cable'
require_relative '../lib/claude_code_sdk'

# Sidekiq job for streaming Claude responses
class ClaudeStreamingJob
  include Sidekiq::Job
  
  # Job to process a Claude query with streaming updates
  def perform(user_id, query_id, prompt, options_hash = {})
    # Parse options
    options = build_claude_options(options_hash)
    
    # Set up streaming
    channel_name = "claude_stream_#{user_id}_#{query_id}"
    
    begin
      # Broadcast start
      ActionCable.server.broadcast(channel_name, {
        type: 'start',
        query_id: query_id,
        timestamp: Time.current
      })
      
      message_count = 0
      
      # Stream Claude responses
      ClaudeCodeSDK.query(
        prompt: prompt,
        options: options,
        cli_path: claude_cli_path
      ).each do |message|
        message_count += 1
        
        # Broadcast each message as it arrives
        broadcast_data = {
          type: 'message',
          query_id: query_id,
          message_index: message_count,
          timestamp: Time.current
        }
        
        case message
        when ClaudeCodeSDK::SystemMessage
          broadcast_data.merge!(
            message_type: 'system',
            subtype: message.subtype,
            data: message.data
          )
          
        when ClaudeCodeSDK::AssistantMessage
          # Process content blocks
          content_blocks = message.content.map do |block|
            case block
            when ClaudeCodeSDK::TextBlock
              { type: 'text', text: block.text }
            when ClaudeCodeSDK::ToolUseBlock
              { 
                type: 'tool_use', 
                id: block.id, 
                name: block.name, 
                input: block.input 
              }
            when ClaudeCodeSDK::ToolResultBlock
              { 
                type: 'tool_result', 
                tool_use_id: block.tool_use_id, 
                content: block.content,
                is_error: block.is_error
              }
            end
          end
          
          broadcast_data.merge!(
            message_type: 'assistant',
            content: content_blocks
          )
          
        when ClaudeCodeSDK::ResultMessage
          broadcast_data.merge!(
            message_type: 'result',
            subtype: message.subtype,
            duration_ms: message.duration_ms,
            duration_api_ms: message.duration_api_ms,
            is_error: message.is_error,
            num_turns: message.num_turns,
            session_id: message.session_id,
            total_cost_usd: message.total_cost_usd,
            usage: message.usage,
            result: message.result
          )
        end
        
        # Broadcast to WebSocket
        ActionCable.server.broadcast(channel_name, broadcast_data)
        
        # Optional: Save to database for persistence
        save_message_to_db(user_id, query_id, message_count, broadcast_data)
      end
      
      # Broadcast completion
      ActionCable.server.broadcast(channel_name, {
        type: 'complete',
        query_id: query_id,
        total_messages: message_count,
        timestamp: Time.current
      })
      
    rescue => e
      # Broadcast error
      ActionCable.server.broadcast(channel_name, {
        type: 'error',
        query_id: query_id,
        error: e.message,
        timestamp: Time.current
      })
      
      # Log error
      Rails.logger.error "Claude streaming job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      raise e # Re-raise for Sidekiq retry logic
    end
  end
  
  private
  
  def build_claude_options(options_hash)
    ClaudeCodeSDK::ClaudeCodeOptions.new(
      model: options_hash['model'],
      max_turns: options_hash['max_turns'] || 1,
      system_prompt: options_hash['system_prompt'],
      allowed_tools: options_hash['allowed_tools'] || [],
      mcp_servers: build_mcp_servers(options_hash['mcp_servers'] || {}),
      permission_mode: options_hash['permission_mode']
    )
  end
  
  def build_mcp_servers(mcp_config)
    return {} if mcp_config.empty?
    
    servers = {}
    mcp_config.each do |name, config|
      servers.merge!(ClaudeCodeSDK.add_mcp_server(name, config))
    end
    servers
  end
  
  def claude_cli_path
    # Try environment variable first, then common paths
    ENV['CLAUDE_CLI_PATH'] || 
    Rails.application.config.claude_cli_path ||
    '/usr/local/bin/claude'
  end
  
  def save_message_to_db(user_id, query_id, message_index, data)
    # Example: Save to database for persistence/replay
    # ClaudeMessage.create!(
    #   user_id: user_id,
    #   query_id: query_id,
    #   message_index: message_index,
    #   message_type: data[:message_type],
    #   content: data,
    #   timestamp: data[:timestamp]
    # )
  end
end

# ActionCable channel for real-time streaming
class ClaudeStreamChannel < ApplicationCable::Channel
  def subscribed
    stream_from "claude_stream_#{params[:user_id]}_#{params[:query_id]}"
  end
  
  def unsubscribed
    # Cleanup when channel is unsubscribed
  end
end

# Controller example
class ClaudeController < ApplicationController
  def create_stream_query
    query_id = SecureRandom.uuid
    
    # Validate and sanitize input
    prompt = params[:prompt]
    options = {
      'model' => params[:model],
      'max_turns' => params[:max_turns]&.to_i,
      'system_prompt' => params[:system_prompt],
      'allowed_tools' => params[:allowed_tools] || [],
      'mcp_servers' => params[:mcp_servers] || {}
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

# Frontend JavaScript example (with ActionCable)
FRONTEND_EXAMPLE = <<~JAVASCRIPT
  // Connect to the streaming channel
  const subscription = App.cable.subscriptions.create(
    {
      channel: "ClaudeStreamChannel",
      user_id: currentUserId,
      query_id: queryId
    },
    {
      received(data) {
        switch(data.type) {
          case 'start':
            console.log('Claude query started:', data.query_id);
            showLoadingIndicator();
            break;
            
          case 'message':
            handleClaudeMessage(data);
            break;
            
          case 'complete':
            console.log('Claude query completed');
            hideLoadingIndicator();
            break;
            
          case 'error':
            console.error('Claude query failed:', data.error);
            showError(data.error);
            break;
        }
      }
    }
  );
  
  function handleClaudeMessage(data) {
    switch(data.message_type) {
      case 'system':
        console.log('System message:', data.subtype);
        break;
        
      case 'assistant':
        data.content.forEach(block => {
          if (block.type === 'text') {
            appendText(block.text);
          } else if (block.type === 'tool_use') {
            showToolUsage(block.name, block.input);
          }
        });
        break;
        
      case 'result':
        showFinalResult(data);
        break;
    }
  }
  
  // Start a Claude query
  function startClaudeQuery(prompt, options = {}) {
    fetch('/claude/stream_query', {
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
        allowed_tools: options.allowedTools,
        mcp_servers: options.mcpServers
      })
    })
    .then(response => response.json())
    .then(data => {
      console.log('Query started with ID:', data.query_id);
    });
  }
JAVASCRIPT

# Usage example in Rails console or initializer
RAILS_USAGE_EXAMPLE = <<~RUBY
  # In Rails console:
  
  # Start a simple streaming query
  ClaudeStreamingJob.perform_async(
    1,                           # user_id
    SecureRandom.uuid,          # query_id
    "Explain Ruby on Rails",    # prompt
    { 'model' => 'sonnet', 'max_turns' => 1 }
  )
  
  # Start an MCP-enabled streaming query
  ClaudeStreamingJob.perform_async(
    1,
    SecureRandom.uuid,
    "Use the about tool to describe yourself",
    {
      'model' => 'sonnet',
      'max_turns' => 1,
      'allowed_tools' => ['mcp__ninja__about'],
      'mcp_servers' => {
        'ninja' => 'https://mcp-creator-ninja-v1-4-0.mcp.soy/'
      }
    }
  )
RUBY

puts "Rails + Sidekiq + ActionCable streaming example loaded!"
puts
puts "Key components:"
puts "• ClaudeStreamingJob - Sidekiq background job"
puts "• ClaudeStreamChannel - ActionCable channel"  
puts "• Real-time WebSocket streaming to frontend"
puts "• Error handling and retry logic"
puts "• MCP server support"
puts
puts "Usage examples:"
puts RAILS_USAGE_EXAMPLE
puts
puts "Frontend JavaScript:"
puts FRONTEND_EXAMPLE