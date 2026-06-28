# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.

require_relative "container/controller"

# This is a workaround for Ruby's inconsistent handling of SIGINT.
# See <https://github.com/ruby/ruby/pull/17533> for more details.
::Signal.trap(:INT){::Thread.current.raise(Interrupt)}
