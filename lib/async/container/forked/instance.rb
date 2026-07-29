# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../notify/pipe"

module Async
	module Container
		module Forked
			# Represents a running child process from the point of view of the child process.
			class Instance < Notify::Pipe
				# Wrap an instance around the {Channel} instance from within the forked child.
				# @parameter channel [Channel] The channel to use for communication.
				# @parameter name [String] The name of the process.
				def self.for(channel, name: nil)
					instance = self.new(channel.out)
					
					# The child process won't be reading from the channel:
					channel.close_read
					
					instance.name = name
					
					return instance
				end
				
				# Initialize the child process instance.
				#
				# @parameter io [IO] The IO object to use for communication.
				def initialize(io)
					super
					
					@name = nil
				end
				
				# Generate a hash representation of the process.
				#
				# @returns [Hash] The process as a hash, including `process_id` and `name`.
				def as_json(...)
					{
						process_id: ::Process.pid,
						name: @name,
					}
				end
				
				# Generate a JSON representation of the process.
				#
				# @returns [String] The process as JSON.
				def to_json(...)
					as_json.to_json(...)
				end
				
				# Set the process title to the specified value.
				#
				# @parameter value [String] The name of the process.
				def name= value
					@name = value
					
					# This sets the process title to an empty string if the name is nil:
					::Process.setproctitle(@name.to_s)
				end
				
				# @returns [String] The name of the process.
				def name
					@name
				end
				
				# Replace the current child process with a different one. Forwards arguments and options to {::Process.exec}.
				# This method replaces the child process with the new executable, thus this method never returns.
				#
				# @parameter arguments [Array] The arguments to pass to the new process.
				# @parameter ready [Boolean] If true, informs the parent process that the child is ready before exec. The notification pipe will still be passed to the exec'd process to prevent premature termination.
				# @parameter options [Hash] Additional options to pass to {::Process.exec}.
				def exec(*arguments, ready: true, **options)
					# Always set up the notification pipe to be inherited by the exec'd process.
					# This prevents the pipe from closing, which would trigger hang prevention and SIGKILL.
					self.before_spawn(arguments, options)
					
					if ready
						self.ready!(status: "(exec)")
					end
					
					::Process.exec(*arguments, **options)
				end
			end
		end
	end
end
