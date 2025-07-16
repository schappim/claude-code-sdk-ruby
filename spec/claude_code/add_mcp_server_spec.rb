# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClaudeCode do
  describe '.add_mcp_server' do
    context 'with a URL string' do
      it 'creates an McpHttpServerConfig for HTTPS URLs' do
        result = described_class.add_mcp_server('ninja', 'https://mcp-creator-ninja-v1-4-0.mcp.soy/')
        
        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly('ninja')
        
        config = result['ninja']
        expect(config).to be_a(ClaudeCode::McpHttpServerConfig)
        expect(config.url).to eq('https://mcp-creator-ninja-v1-4-0.mcp.soy/')
        expect(config.type).to eq('http')
      end
      
      it 'creates an McpHttpServerConfig for HTTP URLs' do
        result = described_class.add_mcp_server('test', 'http://localhost:3000/mcp')
        
        config = result['test']
        expect(config).to be_a(ClaudeCode::McpHttpServerConfig)
        expect(config.url).to eq('http://localhost:3000/mcp')
      end
      
      it 'creates an McpStdioServerConfig for command strings' do
        result = described_class.add_mcp_server('local', 'node my-server.js --port 3000')
        
        config = result['local']
        expect(config).to be_a(ClaudeCode::McpStdioServerConfig)
        expect(config.command).to eq('node')
        expect(config.args).to eq(['my-server.js', '--port', '3000'])
        expect(config.type).to eq('stdio')
      end
      
      it 'handles single word commands' do
        result = described_class.add_mcp_server('simple', 'my-mcp-server')
        
        config = result['simple']
        expect(config).to be_a(ClaudeCode::McpStdioServerConfig)
        expect(config.command).to eq('my-mcp-server')
        expect(config.args).to eq([])
      end
    end
    
    context 'with a hash configuration' do
      it 'creates an McpHttpServerConfig for HTTP configs' do
        result = described_class.add_mcp_server('api', {
          url: 'https://api.example.com/mcp',
          headers: { 'Authorization' => 'Bearer token123' }
        })
        
        config = result['api']
        expect(config).to be_a(ClaudeCode::McpHttpServerConfig)
        expect(config.url).to eq('https://api.example.com/mcp')
        expect(config.headers).to eq({ 'Authorization' => 'Bearer token123' })
      end
      
      it 'creates an McpHttpServerConfig even with type specified' do
        result = described_class.add_mcp_server('events', {
          type: 'http',
          url: 'https://events.example.com/stream',
          headers: { 'X-API-Key' => 'secret' }
        })
        
        config = result['events']
        expect(config).to be_a(ClaudeCode::McpHttpServerConfig)
        expect(config.url).to eq('https://events.example.com/stream')
        expect(config.headers).to eq({ 'X-API-Key' => 'secret' })
        expect(config.type).to eq('http')
      end
      
      it 'creates an McpStdioServerConfig for stdio configs' do
        result = described_class.add_mcp_server('github', {
          command: 'npx',
          args: ['@modelcontextprotocol/server-github'],
          env: { 'GITHUB_TOKEN' => 'gh_token123' }
        })
        
        config = result['github']
        expect(config).to be_a(ClaudeCode::McpStdioServerConfig)
        expect(config.command).to eq('npx')
        expect(config.args).to eq(['@modelcontextprotocol/server-github'])
        expect(config.env).to eq({ 'GITHUB_TOKEN' => 'gh_token123' })
      end
      
      it 'handles string keys in hashes' do
        result = described_class.add_mcp_server('stringkeys', {
          'url' => 'https://example.com',
          'headers' => { 'X-Test' => 'value' }
        })
        
        config = result['stringkeys']
        expect(config).to be_a(ClaudeCode::McpHttpServerConfig)
        expect(config.url).to eq('https://example.com')
        expect(config.headers).to eq({ 'X-Test' => 'value' })
      end
      
      it 'raises error for invalid hash config' do
        expect {
          described_class.add_mcp_server('invalid', { invalid: 'config' })
        }.to raise_error(ArgumentError, /Invalid MCP server configuration: missing required fields/)
      end
    end
    
    context 'with pre-built config objects' do
      it 'accepts McpHttpServerConfig objects' do
        config = ClaudeCode::McpHttpServerConfig.new(
          url: 'https://example.com',
          headers: { 'X-Custom' => 'header' }
        )
        
        result = described_class.add_mcp_server('prebuilt', config)
        
        expect(result['prebuilt']).to be(config) # Same object
      end
      
      it 'accepts McpSSEServerConfig objects' do
        config = ClaudeCode::McpSSEServerConfig.new(
          url: 'https://sse.example.com'
        )
        
        result = described_class.add_mcp_server('sse', config)
        
        expect(result['sse']).to be(config)
      end
      
      it 'accepts McpStdioServerConfig objects' do
        config = ClaudeCode::McpStdioServerConfig.new(
          command: 'python',
          args: ['server.py']
        )
        
        result = described_class.add_mcp_server('python', config)
        
        expect(result['python']).to be(config)
      end
    end
    
    context 'with invalid inputs' do
      it 'raises error for invalid types' do
        expect {
          described_class.add_mcp_server('bad', 123)
        }.to raise_error(ArgumentError, /Invalid MCP server configuration type: Integer/)
        
        expect {
          described_class.add_mcp_server('bad', [])
        }.to raise_error(ArgumentError, /Invalid MCP server configuration type: Array/)
      end
    end
    
    context 'integration with query' do
      it 'works with string URL in real usage' do
        # This simulates the exact usage from the user's code
        mcp_servers = described_class.add_mcp_server(
          "ninja",
          "https://mcp-creator-ninja-v1-4-0.mcp.soy/"
        )
        
        expect(mcp_servers).to be_a(Hash)
        expect(mcp_servers['ninja']).to be_a(ClaudeCode::McpHttpServerConfig)
        
        # The config should have a proper to_h method that the CLI can use
        config_hash = mcp_servers['ninja'].to_h
        expect(config_hash).to eq({
          type: 'http',
          url: 'https://mcp-creator-ninja-v1-4-0.mcp.soy/',
          headers: {}
        })
      end
    end
  end
end