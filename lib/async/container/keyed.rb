# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module Async
	module Container
		# Tracks a key/value pair such that unmarked keys can be identified and cleaned up.
		# This helps implement persistent processes that start up child processes per directory or configuration file. If those directories and/or configuration files are removed, the child process can then be cleaned up automatically, because those key/value pairs will not be marked when reloading the container.
		class Keyed
			def initialize(key, value)
				@key = key
				@value = value
				@marked = true
			end
			
			# The key. Normally a symbol or a file-system path.
			# @attribute [Object]
			attr :key
			
			# The value. Normally a child instance of some sort.
			# @attribute [Object]
			attr :value
			
			# Has the instance been marked?
			# @returns [Boolean]
			def marked?
				@marked
			end
			
			# Mark the instance. This will indiciate that the value is still in use/active.
			def mark!
				@marked = true
			end
			
			# Clear the instance. This is normally done before reloading a container.
			def clear!
				@marked = false
			end
			
			# Stop the instance if it was not marked.
			def stop?
				unless @marked
					@value.stop
					return true
				end
			end
		end
	end
end
