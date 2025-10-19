# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "json"

module Async
	module Container
		# Provides a basic multi-thread/multi-process uni-directional communication channel.
		class Channel
			# Initialize the channel using a pipe.
			def initialize(timeout: 1.0)
				@in, @out = ::IO.pipe
				@in.timeout = timeout
			end
			
			# The input end of the pipe.
			# @attribute [IO]
			attr :in
			
			# The output end of the pipe.
			# @attribute [IO]
			attr :out
			
			# Close the input end of the pipe.
			def close_read
				@in.close
			end
			
			# Close the output end of the pipe.
			def close_write
				@out.close
			end
			
			# Close both ends of the pipe.
			def close
				close_read
				close_write
			end
			
			# Receive an object from the pipe.
			# Internally, prefers to receive newline formatted JSON, otherwise returns a hash table with a single key `:line` which contains the line of data that could not be parsed as JSON.
			# @returns [Hash]
			def receive
				if data = @in.gets
					return JSON.parse(data, symbolize_names: true)
				end
			rescue => error
				Console.error(self, "Error during channel receive!", error)
				return nil
			end
		end
	end
end
