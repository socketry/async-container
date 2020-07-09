# frozen_string_literal: true

# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'client'

require 'console/logger'

module Async
	module Container
		module Notify
			# Implements a general process readiness protocol with output to the local console.
			class Console < Client
				# Open a notification client attached to the current console.
				def self.open!(logger = ::Console.logger)
					self.new(logger)
				end
				
				# Initialize the notification client.
				# @parameter logger [Console::Logger] The console logger instance to send messages to.
				def initialize(logger)
					@logger = logger
				end
				
				# Send a message to the console.
				def send(level: :debug, **message)
					@logger.send(level, self) {message}
				end
				
				# Send an error message to the console.
				# @parameters text [String] The details of the error condition.
				# @parameters message [Hash] Additional details to send with the message.
				def error!(text, **message)
					send(status: text, level: :error, **message)
				end
			end
		end
	end
end
