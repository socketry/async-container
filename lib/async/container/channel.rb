# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require 'json'

module Async
	module Container
		# Provides a basic multi-thread/multi-process uni-directional communication channel.
		class Channel
			# Initialize the channel using a pipe.
			def initialize
				@in, @out = ::IO.pipe
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
					begin
						return JSON.parse(data, symbolize_names: true)
					rescue
						return {line: data}
					end
				end
			end
		end
	end
end
