# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: [:spec, :rubocop]

desc 'Run all tests and linting'
task test: [:spec, :rubocop]

desc 'Run tests with coverage report'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:spec].invoke
end

desc 'Generate YARD documentation'
task :docs do
  sh 'yard doc'
end

desc 'Setup development environment'
task :setup do
  sh 'bundle install'
  puts 'Development environment setup complete!'
  puts 'Run `rake test` to run tests'
  puts 'Run `rake docs` to generate documentation'
end