# frozen_string_literal: true

# Coverage reporting
if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    minimum_coverage 80
  end
end

require 'bundler/setup'
require 'claude_code'

# Include support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomization
  Kernel.srand(config.seed)

  # Allow focused tests in development
  config.filter_run_when_matching(:focus)

  # Verify mocks
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  # Shared context for tests
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Show more verbose output when running a single test
  config.default_formatter = 'doc' if config.files_to_run.one?
end

# Helper method to create a mock subprocess
def mock_subprocess(stdout_lines: [], stderr_lines: [], exit_status: 0)
  process = instance_double(Process::Waiter)

  stdout = instance_double(IO)
  stderr = instance_double(IO)

  allow(stdout).to receive(:each_line) do |&block|
    stdout_lines.each(&block)
  end

  allow(stderr).to receive(:each_line) do |&block|
    stderr_lines.each(&block)
  end

  allow(process).to receive_messages(
    stdout: stdout,
    stderr: stderr,
    value: instance_double(Process::Status, exitstatus: exit_status),
    running?: exit_status == 0,
    alive?: exit_status == 0
  )
  allow(process).to receive(:join)

  process
end

# Test helpers for message creation
module TestHelpers
  def text_block(text)
    ClaudeCode::TextBlock.new(text)
  end

  def tool_use_block(id:, name:, input:)
    ClaudeCode::ToolUseBlock.new(id: id, name: name, input: input)
  end

  def tool_result_block(tool_use_id:, content:, is_error: false)
    ClaudeCode::ToolResultBlock.new(
      tool_use_id: tool_use_id,
      content: content,
      is_error: is_error
    )
  end

  def assistant_message(content:)
    ClaudeCode::AssistantMessage.new(content)
  end

  def user_message(content:)
    ClaudeCode::UserMessage.new(content)
  end

  def result_message(
    subtype:,
    duration_ms:,
    duration_api_ms:,
    is_error: false,
    num_turns: 1,
    session_id: 'test-session',
    total_cost_usd: 0.001,
    usage: nil,
    result: nil
  )
    ClaudeCode::ResultMessage.new(
      subtype: subtype,
      duration_ms: duration_ms,
      duration_api_ms: duration_api_ms,
      is_error: is_error,
      num_turns: num_turns,
      session_id: session_id,
      total_cost_usd: total_cost_usd,
      usage: usage,
      result: result
    )
  end

  def claude_options(**kwargs)
    ClaudeCode::ClaudeCodeOptions.new(**kwargs)
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end