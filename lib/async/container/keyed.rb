# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

module Async
	module Container
		# Tracks a key/value pair such that unmarked keys can be identified and cleaned up.
		# This helps implement persistent processes that start up child processes per directory or configuration file. If those directories and/or configuration files are removed, the child process can then be cleaned up automatically, because those key/value pairs will not be marked when reloading the container.
		class Keyed
			# Initialize the keyed instance
			#
			# @parameter key [Object] The key.
			# @parameter value [Object] The value.
			def initialize(key, value)
				@key = key
				@value = value
				@marked = true
			end
			
			# @attribute [Object] The key value, normally a symbol or a file-system path.
			attr :key
			
			# @attribute [Object] The value, normally a child instance.
			attr :value
			
			# @returns [Boolean] True if the instance has been marked, during reloading the container.
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
			#
			# @returns [Boolean] True if the instance was stopped.
			def stop?
				unless @marked
					@value.stop
					return true
				end
			end
		end
	end
end
