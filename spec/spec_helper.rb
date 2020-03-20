# frozen_string_literal: true

require 'covered/rspec'

# Shared rspec helpers:
require "async/rspec"

if RUBY_PLATFORM =~ /darwin/i
	QUANTUM = 2.0
else
	QUANTUM = 1.0
end

RSpec.configure do |config|
	# Enable flags like --only-failures and --next-failure
	config.example_status_persistence_file_path = ".rspec_status"
	
	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end
