# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

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
