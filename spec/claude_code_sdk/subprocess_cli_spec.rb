# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClaudeCodeSDK::SubprocessCLITransport do
  let(:prompt) { 'test prompt' }
  let(:options) { ClaudeCodeSDK::ClaudeCodeOptions.new }
  let(:cli_path) { '/usr/local/bin/claude' }

  describe '#find_cli' do
    context 'when CLI is not found' do
      it 'raises CLINotFoundError with helpful message' do
        transport = described_class.new(prompt: prompt, options: options)
        
        allow(transport).to receive(:which).and_return(nil)
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)

        expect { transport.send(:find_cli) }
          .to raise_error(ClaudeCodeSDK::CLINotFoundError) do |error|
            expect(error.message).to include('Claude Code requires Node.js')
            expect(error.message).to include('npm install -g @anthropic-ai/claude-code')
          end
      end

      it 'includes Node.js installation instructions when Node.js is missing' do
        transport = described_class.new(prompt: prompt, options: options)
        
        allow(transport).to receive(:which).with('claude').and_return(nil)
        allow(transport).to receive(:which).with('node').and_return(nil)
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)

        expect { transport.send(:find_cli) }
          .to raise_error(ClaudeCodeSDK::CLINotFoundError) do |error|
            expect(error.message).to include('Node.js, which is not installed')
            expect(error.message).to include('https://nodejs.org/')
          end
      end
    end

    context 'when CLI is found in PATH' do
      it 'returns the CLI path' do
        transport = described_class.new(prompt: prompt, options: options)
        
        allow(transport).to receive(:which).with('claude').and_return('/usr/local/bin/claude')

        expect(transport.send(:find_cli)).to eq('/usr/local/bin/claude')
      end
    end

    context 'when CLI is found in common locations' do
      it 'returns the first found path' do
        transport = described_class.new(prompt: prompt, options: options)
        
        allow(transport).to receive(:which).with('claude').and_return(nil)
        
        # Mock the first location to exist
        first_path = Pathname.new(File.expand_path('~/.claude/local/claude'))
        allow(Pathname).to receive(:new).and_call_original
        allow(Pathname).to receive(:new).with(File.expand_path('~/.claude/local/claude')).and_return(first_path)
        allow(first_path).to receive(:exist?).and_return(true)
        allow(first_path).to receive(:file?).and_return(true)

        expect(transport.send(:find_cli)).to eq(first_path.to_s)
      end
    end
  end

  describe '#build_command' do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path
      )
    end

    it 'builds basic CLI command' do
      cmd = transport.send(:build_command)

      expect(cmd[0]).to eq(cli_path)
      expect(cmd).to include('--output-format', 'stream-json')
      expect(cmd).to include('--verbose')
      expect(cmd).to include('--print', prompt)
    end

    it 'includes options in command' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(
        system_prompt: 'Be helpful',
        allowed_tools: ['Read', 'Write'],
        disallowed_tools: ['Bash'],
        model: 'claude-3-5-sonnet',
        permission_mode: 'accept_edits',
        max_turns: 5
      )

      transport = described_class.new(
        prompt: 'test',
        options: options,
        cli_path: cli_path
      )

      cmd = transport.send(:build_command)

      expect(cmd).to include('--system-prompt', 'Be helpful')
      expect(cmd).to include('--allowedTools', 'Read,Write')
      expect(cmd).to include('--disallowedTools', 'Bash')
      expect(cmd).to include('--model', 'claude-3-5-sonnet')
      expect(cmd).to include('--permission-mode', 'accept_edits')
      expect(cmd).to include('--max-turns', '5')
    end

    it 'includes session continuation options' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(
        continue_conversation: true,
        resume: 'session-123'
      )

      transport = described_class.new(
        prompt: 'Continue from before',
        options: options,
        cli_path: cli_path
      )

      cmd = transport.send(:build_command)

      expect(cmd).to include('--continue')
      expect(cmd).to include('--resume', 'session-123')
    end

    it 'includes MCP server configuration' do
      mcp_servers = {
        'test_server' => ClaudeCodeSDK::McpHttpServerConfig.new(
          url: 'http://test.com'
        )
      }
      
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(
        mcp_servers: mcp_servers
      )

      transport = described_class.new(
        prompt: 'test',
        options: options,
        cli_path: cli_path
      )

      cmd = transport.send(:build_command)

      expect(cmd).to include('--mcp-config')
      mcp_config_index = cmd.index('--mcp-config')
      mcp_config_json = cmd[mcp_config_index + 1]
      parsed_config = JSON.parse(mcp_config_json)
      
      expect(parsed_config['mcpServers']).to have_key('test_server')
    end
  end

  describe '#connect and #disconnect' do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path
      )
    end

    it 'manages process lifecycle' do
      stdin_w = instance_double(IO)
      stdout_r = instance_double(IO)
      stderr_r = instance_double(IO)
      process = instance_double(Process::Waiter, pid: 12345, alive?: true)

      allow(Open3).to receive(:popen3).and_return([stdin_w, stdout_r, stderr_r, process])
      allow(stdin_w).to receive(:close)
      allow(Process).to receive(:kill)
      allow(process).to receive(:join)
      allow(stdout_r).to receive(:close)
      allow(stderr_r).to receive(:close)

      transport.connect
      expect(transport.connected?).to be(true)

      transport.disconnect
      expect(Process).to have_received(:kill).with('INT', 12345)
    end

    it 'handles connection errors gracefully' do
      allow(Open3).to receive(:popen3).and_raise(Errno::ENOENT.new('No such file'))

      expect { transport.connect }
        .to raise_error(ClaudeCodeSDK::CLINotFoundError, /Claude Code not found/)
    end

    it 'handles working directory errors' do
      options = ClaudeCodeSDK::ClaudeCodeOptions.new(cwd: '/nonexistent/path')
      transport = described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path
      )

      allow(Open3).to receive(:popen3).and_raise(Errno::ENOENT.new('No such file'))

      expect { transport.connect }
        .to raise_error(ClaudeCodeSDK::CLIConnectionError, /Working directory does not exist/)
    end
  end

  describe '#receive_messages' do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path
      )
    end

    it 'requires connection' do
      expect do
        transport.receive_messages { |_| nil }
      end.to raise_error(ClaudeCodeSDK::CLIConnectionError, 'Not connected')
    end

    it 'parses JSON messages from stdout' do
      message1 = { 'type' => 'assistant', 'content' => 'Hello' }
      message2 = { 'type' => 'result', 'success' => true }
      
      stdout = StringIO.new
      stdout.puts(message1.to_json)
      stdout.puts(message2.to_json)
      stdout.rewind
      
      stderr = StringIO.new
      process = instance_double(Process::Waiter, 
                              value: instance_double(Process::Status, exitstatus: 0))
      
      transport.instance_variable_set(:@stdout, stdout)
      transport.instance_variable_set(:@stderr, stderr)
      transport.instance_variable_set(:@process, process)

      messages = []
      transport.receive_messages { |msg| messages << msg }

      expect(messages.length).to eq(2)
      expect(messages[0]['type']).to eq('assistant')
      expect(messages[1]['type']).to eq('result')
    end

    it 'handles process errors' do
      stdout = StringIO.new
      stderr = StringIO.new('Error message')
      process = instance_double(Process::Waiter, 
                              value: instance_double(Process::Status, exitstatus: 1))
      
      transport.instance_variable_set(:@stdout, stdout)
      transport.instance_variable_set(:@stderr, stderr)
      transport.instance_variable_set(:@process, process)

      expect do
        transport.receive_messages { |_| nil }
      end.to raise_error(ClaudeCodeSDK::ProcessError) do |error|
        expect(error.exit_code).to eq(1)
        expect(error.stderr).to include('Error message')
      end
    end
  end

  describe '#which' do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path
      )
    end

    it 'finds executable in PATH' do
      allow(ENV).to receive(:[]).with('PATH').and_return('/usr/bin:/usr/local/bin')
      allow(ENV).to receive(:[]).with('PATHEXT').and_return(nil)
      allow(File).to receive(:executable?).and_return(false)
      allow(File).to receive(:executable?).with('/usr/local/bin/claude').and_return(true)
      allow(File).to receive(:directory?).with('/usr/local/bin/claude').and_return(false)

      result = transport.send(:which, 'claude')
      expect(result).to eq('/usr/local/bin/claude')
    end

    it 'returns nil when command not found' do
      allow(ENV).to receive(:[]).with('PATH').and_return('/usr/bin')
      allow(ENV).to receive(:[]).with('PATHEXT').and_return(nil)
      allow(File).to receive(:executable?).and_return(false)

      result = transport.send(:which, 'nonexistent')
      expect(result).to be_nil
    end
  end
end