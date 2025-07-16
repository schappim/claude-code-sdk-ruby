# frozen_string_literal: true

# Additional test helpers for RSpec
module SpecTestHelpers
  # Create a mock CLI process that can simulate various scenarios
  def mock_cli_process(responses: [], exit_code: 0, stderr_output: '')
    stdout_io = StringIO.new
    stderr_io = StringIO.new(stderr_output)
    
    # Write responses to stdout
    responses.each do |response|
      stdout_io.puts(response.to_json)
    end
    stdout_io.rewind
    
    process = instance_double(Process::Waiter)
    allow(process).to receive_messages(
      alive?: true,
      pid: 12345,
      value: instance_double(Process::Status, exitstatus: exit_code),
      join: nil
    )
    
    [stdout_io, stderr_io, process]
  end

  # Create test message data structures
  def test_assistant_message(text = 'Hello, World!')
    {
      'type' => 'assistant',
      'message' => {
        'role' => 'assistant',
        'content' => [
          { 'type' => 'text', 'text' => text }
        ]
      }
    }
  end

  def test_tool_use_message(tool_name = 'Read', input = { 'file_path' => '/test.txt' })
    {
      'type' => 'assistant',
      'message' => {
        'role' => 'assistant',
        'content' => [
          {
            'type' => 'tool_use',
            'id' => 'tool-123',
            'name' => tool_name,
            'input' => input
          }
        ]
      }
    }
  end

  def test_result_message(cost: 0.001, duration: 1000)
    {
      'type' => 'result',
      'subtype' => 'success',
      'duration_ms' => duration,
      'duration_api_ms' => duration - 200,
      'is_error' => false,
      'num_turns' => 1,
      'session_id' => 'test-session',
      'total_cost_usd' => cost
    }
  end

  def test_system_message(subtype: 'init', tools: [])
    {
      'type' => 'system',
      'subtype' => subtype,
      'tools' => tools,
      'session_id' => 'test-session',
      'model' => 'claude-3-5-sonnet'
    }
  end

  # Stub the CLI path finding for tests
  def stub_cli_found(path = '/usr/local/bin/claude')
    allow_any_instance_of(ClaudeCodeSDK::SubprocessCLITransport)
      .to receive(:find_cli).and_return(path)
  end

  def stub_cli_not_found
    allow_any_instance_of(ClaudeCodeSDK::SubprocessCLITransport)
      .to receive(:find_cli).and_raise(ClaudeCodeSDK::CLINotFoundError.new('Test: CLI not found'))
  end

  # Mock Open3.popen3 for subprocess testing
  def mock_popen3(stdout_lines: [], stderr_lines: [], exit_status: 0)
    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe
    stdin_r, stdin_w = IO.pipe

    # Write test data
    stdout_lines.each { |line| stdout_w.puts(line) }
    stderr_lines.each { |line| stderr_w.puts(line) }
    stdout_w.close
    stderr_w.close
    stdin_r.close

    # Mock process
    process = instance_double(Process::Waiter)
    allow(process).to receive_messages(
      pid: 12345,
      alive?: exit_status == 0,
      value: instance_double(Process::Status, exitstatus: exit_status),
      join: nil
    )

    allow(Open3).to receive(:popen3).and_return([stdin_w, stdout_r, stderr_r, process])
    
    process
  end
end

RSpec.configure do |config|
  config.include SpecTestHelpers
end