#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/claude_code_sdk'

# Example: Different authentication methods for Claude Code SDK

puts "=== Authentication Examples ==="

# Method 1: Using ANTHROPIC_API_KEY environment variable
puts "\n1. Using ANTHROPIC_API_KEY environment variable"
puts "Set your API key:"
puts "export ANTHROPIC_API_KEY='your-api-key-here'"

if ENV['ANTHROPIC_API_KEY']
  puts "✅ ANTHROPIC_API_KEY is set"
  
  # Test basic query with API key authentication
  puts "\nTesting with API key authentication..."
  ClaudeCodeSDK.query("What is 2 + 2?") do |message|
    case message
    when ClaudeCodeSDK::AssistantMessage
      message.content.each do |block|
        if block.is_a?(ClaudeCodeSDK::TextBlock)
          puts "🤖 #{block.text}"
          break
        end
      end
    when ClaudeCodeSDK::ResultMessage
      puts "💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
    end
  end
else
  puts "❌ ANTHROPIC_API_KEY not set"
  puts "Please set your API key before running this example"
end

# Method 2: Amazon Bedrock authentication
puts "\n2. Using Amazon Bedrock"
puts "Set environment variables:"
puts "export CLAUDE_CODE_USE_BEDROCK=1"
puts "export AWS_ACCESS_KEY_ID='your-aws-access-key'"
puts "export AWS_SECRET_ACCESS_KEY='your-aws-secret-key'"
puts "export AWS_REGION='us-west-2'"

if ENV['CLAUDE_CODE_USE_BEDROCK']
  puts "✅ Amazon Bedrock authentication enabled"
  
  # Test with Bedrock
  puts "\nTesting with Bedrock authentication..."
  begin
    ClaudeCodeSDK.query("Hello from Bedrock!") do |message|
      case message
      when ClaudeCodeSDK::AssistantMessage
        message.content.each do |block|
          if block.is_a?(ClaudeCodeSDK::TextBlock)
            puts "🤖 #{block.text}"
            break
          end
        end
      when ClaudeCodeSDK::ResultMessage
        puts "💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
      end
    end
  rescue ClaudeCodeSDK::CLIConnectionError => e
    puts "❌ Bedrock connection failed: #{e.message}"
  end
else
  puts "❌ Amazon Bedrock not configured"
end

# Method 3: Google Vertex AI authentication
puts "\n3. Using Google Vertex AI"
puts "Set environment variables:"
puts "export CLAUDE_CODE_USE_VERTEX=1"
puts "export GOOGLE_APPLICATION_CREDENTIALS='path/to/service-account.json'"
puts "export GOOGLE_CLOUD_PROJECT='your-project-id'"

if ENV['CLAUDE_CODE_USE_VERTEX']
  puts "✅ Google Vertex AI authentication enabled"
  
  # Test with Vertex AI
  puts "\nTesting with Vertex AI authentication..."
  begin
    ClaudeCodeSDK.query("Hello from Vertex AI!") do |message|
      case message
      when ClaudeCodeSDK::AssistantMessage
        message.content.each do |block|
          if block.is_a?(ClaudeCodeSDK::TextBlock)
            puts "🤖 #{block.text}"
            break
          end
        end
      when ClaudeCodeSDK::ResultMessage
        puts "💰 Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
      end
    end
  rescue ClaudeCodeSDK::CLIConnectionError => e
    puts "❌ Vertex AI connection failed: #{e.message}"
  end
else
  puts "❌ Google Vertex AI not configured"
end

# Method 4: Programmatically setting environment variables
puts "\n4. Setting authentication programmatically"
puts "You can also set authentication in your Ruby code:"

puts <<~RUBY
  # Set API key programmatically (not recommended for production)
  ENV['ANTHROPIC_API_KEY'] = 'your-api-key-here'
  
  # Or for Amazon Bedrock
  ENV['CLAUDE_CODE_USE_BEDROCK'] = '1'
  ENV['AWS_ACCESS_KEY_ID'] = 'your-access-key'
  ENV['AWS_SECRET_ACCESS_KEY'] = 'your-secret-key'
  ENV['AWS_REGION'] = 'us-west-2'
  
  # Or for Google Vertex AI
  ENV['CLAUDE_CODE_USE_VERTEX'] = '1'
  ENV['GOOGLE_APPLICATION_CREDENTIALS'] = 'path/to/service-account.json'
  ENV['GOOGLE_CLOUD_PROJECT'] = 'your-project-id'
RUBY

puts "\n⚠️  Security Note:"
puts "For production applications, use secure methods to store credentials:"
puts "- Environment variables"
puts "- AWS IAM roles"
puts "- Google Cloud service accounts"
puts "- Secret management services"
puts "- Never commit API keys to version control"

puts "\n✅ Authentication examples completed!"