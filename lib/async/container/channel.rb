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
