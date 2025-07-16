# MCP Integration

The Ruby Claude Code SDK provides ergonomic integration with Model Context Protocol (MCP) servers, allowing you to extend Claude's capabilities with custom tools and resources.

## Quick Start

### Ultra-Convenient Method

```ruby
# Simplest way to use MCP
ClaudeCode.quick_mcp_query(
  "Use the about tool to describe yourself",
  server_name: "ninja",
  server_url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/",
  tools: "about"  # String or array of tools
).each do |message|
  # Process streaming MCP responses
end
```

## MCP Server Configuration

### 1. HTTP/HTTPS Servers

```ruby
# Simple URL string (auto-detected as HTTP)
mcp_servers = ClaudeCode.add_mcp_server(
  "my_server",
  "https://my-mcp-server.com/"
)

# Explicit HTTP configuration with headers
mcp_servers = ClaudeCode.add_mcp_server("api_server", {
  type: "http",
  url: "https://api.example.com/mcp",
  headers: {
    "Authorization" => "Bearer token123",
    "X-API-Key" => "secret"
  }
})
```

### 2. Server-Sent Events (SSE)

```ruby
mcp_servers = ClaudeCode.add_mcp_server("sse_server", {
  type: "sse",
  url: "https://stream.example.com/mcp",
  headers: {
    "Authorization" => "Bearer token123"
  }
})
```

### 3. Stdio (Command-line) Servers

```ruby
# Simple command string
mcp_servers = ClaudeCode.add_mcp_server(
  "local_server",
  "node my-mcp-server.js"
)

# Full stdio configuration
mcp_servers = ClaudeCode.add_mcp_server("github_server", {
  command: "npx",
  args: ["@modelcontextprotocol/server-github"],
  env: {
    "GITHUB_TOKEN" => "your-github-token"
  }
})
```

## Usage Patterns

### Method 1: Separate MCP Servers Parameter

```ruby
# Build server configuration
mcp_servers = ClaudeCode.add_mcp_server(
  "ninja",
  "https://mcp-creator-ninja-v1-4-0.mcp.soy/"
)

# Configure options
options = ClaudeCode::ClaudeCodeOptions.new(
  allowed_tools: ["mcp__ninja__about"],
  max_turns: 1
)

# Query with MCP servers
ClaudeCode.query(
  prompt: "Use the about tool",
  options: options,
  mcp_servers: mcp_servers
).each do |message|
  # Process response
end
```

### Method 2: Options-based Configuration

```ruby
# Configure everything in options
options = ClaudeCode::ClaudeCodeOptions.new(
  mcp_servers: {
    "ninja" => ClaudeCode::McpHttpServerConfig.new(
      url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/"
    ),
    "local" => ClaudeCode::McpStdioServerConfig.new(
      command: "node",
      args: ["my-server.js"]
    )
  },
  allowed_tools: ["mcp__ninja__about", "mcp__local__my_tool"]
)

ClaudeCode.query(prompt: "Use available tools", options: options)
```

### Method 3: Multiple Servers

```ruby
# Build multiple servers
servers = {}
servers.merge!(ClaudeCode.add_mcp_server("ninja", "https://..."))
servers.merge!(ClaudeCode.add_mcp_server("github", {
  command: "npx",
  args: ["@modelcontextprotocol/server-github"],
  env: { "GITHUB_TOKEN" => ENV["GITHUB_TOKEN"] }
}))
servers.merge!(ClaudeCode.add_mcp_server("filesystem", "npx @modelcontextprotocol/server-filesystem /allowed/path"))

options = ClaudeCode::ClaudeCodeOptions.new(
  allowed_tools: [
    "mcp__ninja__about",
    "mcp__github__search_repositories",
    "mcp__filesystem__read_file"
  ]
)

ClaudeCode.query(
  prompt: "Use available tools to help me",
  options: options,
  mcp_servers: servers
)
```

## Tool Permission Management

### Tool Naming Convention

MCP tools follow the pattern: `mcp__<server_name>__<tool_name>`

```ruby
# Allow specific tools
allowed_tools: ["mcp__ninja__about", "mcp__github__search_repositories"]

# Allow all tools from a server (use with caution)
allowed_tools: ["mcp__ninja"]  # Allows all ninja server tools
```

### Permission Modes

```ruby
options = ClaudeCode::ClaudeCodeOptions.new(
  permission_mode: "default",       # Prompt for dangerous tools
  # permission_mode: "acceptEdits",  # Auto-accept file edits
  # permission_mode: "bypassPermissions"  # Allow all tools (dangerous)
)
```

## Streaming MCP Responses

MCP tool calls stream in real-time, showing tool usage and results as they happen:

```ruby
ClaudeCode.quick_mcp_query(
  "Use multiple tools to analyze this project",
  server_name: "ninja",
  server_url: "https://mcp-creator-ninja-v1-4-0.mcp.soy/",
  tools: ["about", "create"], # Multiple tools
  max_turns: 3
).each do |message|
  case message
  when ClaudeCode::SystemMessage
    puts "🔧 System: MCP servers: #{message.data['mcp_servers'].length}"

  when ClaudeCode::AssistantMessage
    message.content.each do |block|
      case block
      when ClaudeCode::TextBlock
        puts "💬 #{block.text}"

      when ClaudeCode::ToolUseBlock
        puts "🔧 Using tool: #{block.name}"
        puts "📥 Input: #{block.input}"

      when ClaudeCode::ToolResultBlock
        puts "📤 Tool result:"
        puts "   Content: #{block.content}"
        puts "   Error: #{block.is_error ? 'Yes' : 'No'}"
      end
    end

  when ClaudeCode::ResultMessage
    puts "✅ Completed - Cost: $#{format('%.6f', message.total_cost_usd || 0)}"
  end
end
```

## Common MCP Servers

### Creator Ninja (Example/Testing)
```ruby
ClaudeCode.add_mcp_server(
  "ninja",
  "https://mcp-creator-ninja-v1-4-0.mcp.soy/"
)
# Tools: about, create
```

### Filesystem Server
```ruby
ClaudeCode.add_mcp_server("filesystem", {
  command: "npx",
  args: ["-y", "@modelcontextprotocol/server-filesystem", "/allowed/path"],
})
# Tools: read_file, write_file, list_directory, etc.
```

### GitHub Server
```ruby
ClaudeCode.add_mcp_server("github", {
  command: "npx",
  args: ["-y", "@modelcontextprotocol/server-github"],
  env: {
    "GITHUB_TOKEN" => ENV["GITHUB_TOKEN"]
  }
})
# Tools: search_repositories, get_file_contents, create_issue, etc.
```

### Database Server (Example)
```ruby
ClaudeCode.add_mcp_server("database", {
  command: "node",
  args: ["database-mcp-server.js"],
  env: {
    "DATABASE_URL" => ENV["DATABASE_URL"]
  }
})
# Tools: query, schema, insert, update, etc.
```

## Error Handling

```ruby
begin
  ClaudeCode.quick_mcp_query(
    "Use unavailable tool",
    server_name: "ninja",
    server_url: "https://bad-url.com/",
    tools: "nonexistent"
  ).each do |message|
    # Process message
  end
rescue ClaudeCode::ProcessError => e
  puts "MCP server failed: #{e.message}"
  puts "Exit code: #{e.exit_code}"
rescue ClaudeCode::CLIConnectionError => e
  puts "Connection failed: #{e.message}"
end
```

## Rails Integration

```ruby
class McpService
  def self.query_with_mcp(prompt, mcp_config = {})
    servers = build_mcp_servers(mcp_config)

    options = ClaudeCode::ClaudeCodeOptions.new(
      allowed_tools: mcp_config[:allowed_tools] || [],
      permission_mode: "acceptEdits" # For automated environments
    )

    ClaudeCode.query(
      prompt: prompt,
      options: options,
      mcp_servers: servers
    )
  end

  private

  def self.build_mcp_servers(config)
    servers = {}

    config[:servers]&.each do |name, server_config|
      servers.merge!(ClaudeCode.add_mcp_server(name, server_config))
    end

    servers
  end
end

# Usage in Rails
McpService.query_with_mcp(
  "Analyze our GitHub repository",
  servers: {
    "github" => {
      command: "npx",
      args: ["@modelcontextprotocol/server-github"],
      env: { "GITHUB_TOKEN" => Rails.application.credentials.github_token }
    }
  },
  allowed_tools: ["mcp__github__search_repositories", "mcp__github__get_file_contents"]
).each do |message|
  # Process in background job with ActionCable broadcasting
end
```

## Configuration Examples

### Development Environment
```ruby
# config/claude_mcp.yml
development:
  servers:
    filesystem:
      command: "npx"
      args: ["-y", "@modelcontextprotocol/server-filesystem", "<%= Rails.root %>"]
    github:
      command: "npx"
      args: ["-y", "@modelcontextprotocol/server-github"]
      env:
        GITHUB_TOKEN: "<%= Rails.application.credentials.github_token %>"

# Load in initializer
CLAUDE_MCP_CONFIG = YAML.load_file(Rails.root.join('config/claude_mcp.yml'))[Rails.env]
```

### Production Environment
```ruby
# Use environment variables for security
ClaudeCode.add_mcp_server("production_api", {
  type: "http",
  url: ENV["MCP_API_URL"],
  headers: {
    "Authorization" => "Bearer #{ENV['MCP_API_TOKEN']}",
    "X-Environment" => Rails.env
  }
})
```

## Testing MCP Integration

```ruby
# spec/support/mcp_helpers.rb
module McpHelpers
  def mock_mcp_server(name, tools = ["about"])
    allow(ClaudeCode).to receive(:add_mcp_server).with(name, anything).and_return({
      name => double("MockMcpServer")
    })

    allow(ClaudeCode).to receive(:query).and_return([
      mock_assistant_message_with_tools(tools)
    ])
  end

  def mock_assistant_message_with_tools(tools)
    content = tools.map do |tool|
      ClaudeCode::ToolUseBlock.new(
        id: "test-#{tool}",
        name: "mcp__test__#{tool}",
        input: {}
      )
    end

    ClaudeCode::AssistantMessage.new(content)
  end
end

# In tests
RSpec.describe "MCP Integration" do
  include McpHelpers

  it "uses MCP tools" do
    mock_mcp_server("test", ["about"])

    result = ClaudeCode.quick_mcp_query(
      "Test prompt",
      server_name: "test",
      server_url: "http://test.com",
      tools: "about"
    )

    expect(result).to include(have_attributes(class: ClaudeCode::AssistantMessage))
  end
end
```

The MCP integration provides a powerful way to extend Claude's capabilities with custom tools while maintaining the same streaming performance and ergonomic API as the core SDK.
