# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "covered/sus"
include Covered::Sus

ENV["CONSOLE_LEVEL"] ||= "fatal"
ENV["METRICS_BACKEND"] ||= "metrics/backend/test"

def prepare_instrumentation!
	require "metrics"
end

def before_tests(...)
	prepare_instrumentation!
	
	super
end
